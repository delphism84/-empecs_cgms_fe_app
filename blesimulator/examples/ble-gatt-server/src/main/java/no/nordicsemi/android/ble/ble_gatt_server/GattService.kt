/*
 * Copyright (c) 2020, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package no.nordicsemi.android.ble.ble_gatt_server

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.*
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Binder
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import no.nordicsemi.android.ble.BleManager
import no.nordicsemi.android.ble.BleServerManager
import no.nordicsemi.android.ble.data.Data
import no.nordicsemi.android.ble.callback.DataReceivedCallback
import no.nordicsemi.android.ble.observer.ServerObserver
import java.nio.charset.StandardCharsets
import java.util.*
import kotlin.math.roundToInt


/**
 * Advertises a Bluetooth LE GATT service and takes care of its requests. The service
 * runs as a foreground service, which is generally required so that it can run even
 * while the containing app has no UI. It is also possible to have the service
 * started up as part of the OS boot sequence using code similar to the following:
 *
 * <pre>
 *     class OsNotificationReceiver : BroadcastReceiver() {
 *          override fun onReceive(context: Context?, intent: Intent?) {
 *              when (intent?.action) {
 *                  // Start our Gatt service as a result of the system booting up
 *                  Intent.ACTION_BOOT_COMPLETED -> {
 *                     context?.startForegroundService(Intent(context, GattService::class.java))
 *                  }
 *              }
 *          }
 *      }
 * </pre>
 */
class GattService : Service() {
    companion object {
        private const val TAG = "gatt-service"
    }

    private var serverManager: ServerManager? = null

    private lateinit var bluetoothObserver: BroadcastReceiver

    private var bleAdvertiseCallback: BleAdvertiser.Callback? = null

    override fun onCreate() {
        super.onCreate()

        // Setup as a foreground service

        val notificationChannel = NotificationChannel(
                GattService::class.java.simpleName,
                resources.getString(R.string.gatt_service_name),
                NotificationManager.IMPORTANCE_DEFAULT
        )
        val notificationService =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationService.createNotificationChannel(notificationChannel)

        val notification = NotificationCompat.Builder(this, GattService::class.java.simpleName)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(resources.getString(R.string.gatt_service_name))
                .setContentText(resources.getString(R.string.gatt_service_running_notification))
                .setAutoCancel(true)

        startForeground(1, notification.build())

        // Observe OS state changes in BLE

        bluetoothObserver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothAdapter.ACTION_STATE_CHANGED -> {
                        val bluetoothState = intent.getIntExtra(
                                BluetoothAdapter.EXTRA_STATE,
                                -1
                        )
                        when (bluetoothState) {
                            BluetoothAdapter.STATE_ON -> enableBleServices()
                            BluetoothAdapter.STATE_OFF -> disableBleServices()
                        }
                    }
                }
            }
        }
        ContextCompat.registerReceiver(this,
            bluetoothObserver, IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED),
            ContextCompat.RECEIVER_EXPORTED)

        // Startup BLE if we have it

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        if (bluetoothManager.adapter?.isEnabled == true) enableBleServices()
    }

    override fun onDestroy() {
        super.onDestroy()
        disableBleServices()
    }

    override fun onBind(intent: Intent?): IBinder {
        return DataPlane()
    }

    private fun enableBleServices() {
        try {
            val bm = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            val ad = bm.adapter
            if (ad != null && ad.name != "DUSON") {
                ad.name = "DUSON"
            }
        } catch (_: Throwable) {}
        serverManager = ServerManager(this)
        serverManager!!.open()

        bleAdvertiseCallback = BleAdvertiser.Callback()

        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothManager.adapter.bluetoothLeAdvertiser?.startAdvertising(
                BleAdvertiser.settings(),
                BleAdvertiser.advertiseData(),
                bleAdvertiseCallback!!
        )
    }

    private fun disableBleServices() {
        bleAdvertiseCallback?.let {
            val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
            bluetoothManager.adapter.bluetoothLeAdvertiser?.stopAdvertising(it)
            bleAdvertiseCallback = null
        }

        serverManager?.close()
        serverManager = null
    }

    /**
     * Functionality available to clients
     */
    inner class DataPlane : Binder(), DeviceAPI {

        override fun setMyCharacteristicValue(value: String) {
            serverManager?.setMyCharacteristicValue(value)
        }

        fun getStatus(): String = serverManager?.statusStringSafe() ?: "idle"
        fun getLogs(): List<String> { return serverManager?.getLogs() ?: emptyList() }

    }

    /*
     * Manages the entire GATT service, declaring the services and characteristics on offer
     */
    private class ServerManager(val context: Context) : BleServerManager(context), ServerObserver, DeviceAPI {

        companion object {
            private val CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        }

        // CGMS: Measurement (notify) + Ops Control (indicate+write)
        private val measCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_MEASUREMENT,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ,
            descriptor(CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE, byteArrayOf(0, 0))
        )

        private val featureCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_FEATURE,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        private val statusCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_STATUS,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        private val sessionStartCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_SESSION_START_TIME,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        private val sessionRunCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_SESSION_RUN_TIME,
            BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        private val opsCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_OPS_CONTROL,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
            descriptor(CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE, byteArrayOf(0, 0))
        )

        private val racpCharacteristic: BluetoothGattCharacteristic = sharedCharacteristic(
            CgmsProfile.CHAR_RACP,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_INDICATE,
            BluetoothGattCharacteristic.PERMISSION_WRITE,
            descriptor(CLIENT_CHARACTERISTIC_CONFIG_DESCRIPTOR_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE, byteArrayOf(0, 0))
        )

        private val cgmsService = service(
            CgmsProfile.SERVICE_CGMS,
            measCharacteristic,
            featureCharacteristic,
            statusCharacteristic,
            sessionStartCharacteristic,
            sessionRunCharacteristic,
            opsCharacteristic,
            racpCharacteristic
        )

        private val myGattServices = Collections.singletonList(cgmsService)

        private val serverConnections = mutableMapOf<String, ServerConnection>()
        private var next10At = System.currentTimeMillis() + 10_000
        private val logs = java.util.LinkedList<String>()
        private var sessionStartMs: Long = System.currentTimeMillis()
        private var seqCounter: Int = 0
        private var measNotifyEnabled = false
        private var racpIndicateEnabled = false
        private data class StoredRecord(val payload: ByteArray, val seq: Int)
        private val records = java.util.LinkedList<StoredRecord>()
        private val maxRecords = 2000
        private val mainHandler = android.os.Handler(context.mainLooper)
        private var racpSending = false
        private var racpAbort = false
        private var racpSendList: java.util.ArrayList<ByteArray> = java.util.ArrayList()
        private var racpSendIdx = 0

        private fun addLog(s: String) {
            synchronized(logs) {
                logs.addFirst("[" + java.text.SimpleDateFormat("HH:mm:ss").format(java.util.Date()) + "] " + s)
                while (logs.size > 200) logs.removeLast()
            }
        }

        private var simValue = 110
        private var lastSpecYmd = -1
        private var trid = 0
        private var lastNotifyAtMs = System.currentTimeMillis()

        override fun setMyCharacteristicValue(value: String) {
            // interpret as manual mg/dL for quick test
            val mg = value.toIntOrNull() ?: return
            notifyMeasurement(mg)
        }

        fun statusStringSafe(): String {
            val conns = if (serverConnections.isEmpty()) "none" else serverConnections.keys.joinToString(",")
            val remain = ((next10At - System.currentTimeMillis()).coerceAtLeast(0) / 1000).toInt()
            return "connected=$conns, next_notify=${remain}s"
        }

        private fun notifyMeasurement(mgdl: Int) {
            sendMeasurement(mgdl, false)
        }

        private fun sendMeasurement(mgdl: Int, store: Boolean) {
            val now = System.currentTimeMillis()
            val dtSec = ((now - lastNotifyAtMs).coerceAtLeast(1)).toDouble() / 1000.0
            lastNotifyAtMs = now
            val trendPerMin = ((mgdl - simValue).toDouble() * (60.0 / dtSec)).coerceIn(-200.0, 200.0)
            val seq = (seqCounter and 0xFFFF)
            val payload = encodeCgmsMeasurement(mgdl.toDouble(), trendPerMin, timeOffset = seq)
            if (store) {
                synchronized(records) {
                    val rec = StoredRecord(payload, seq)
                    records.add(rec)
                    while (records.size > maxRecords) records.removeFirst()
                }
            }
            serverConnections.values.forEach { it.sendNotificationFor(measCharacteristic, payload) }
            addLog("TX MEAS v=${mgdl}${if (store) " (store)" else ""} seq=${seq}")
            seqCounter = (seqCounter + 1) and 0x7FFFFFFF
        }

        private fun encodeCgmsMeasurement(glucoseMgdl: Double, trendMgdlPerMin: Double, timeOffset: Int): ByteArray {
            // nRF Toolbox CGMMeasurementParser expects: SIZE(1) | FLAGS(1) | SFLOAT(2) | TimeOffset(2) [+ optional fields]
            // Minimal packet: SIZE=6, FLAGS=0x00 (no trend/quality/status), glucose + timeOffset
            val size: Byte = 6
            val flags: Byte = 0x00
            val g = encodeSfloat(glucoseMgdl)
            val toLo = (timeOffset and 0xFF).toByte()
            val toHi = ((timeOffset ushr 8) and 0xFF).toByte()
            return byteArrayOf(size, flags, g[0], g[1], toLo, toHi)
        }

        private fun encodeSfloat(v: Double): ByteArray {
            // simple SFLOAT: exponent=0, mantissa=rounded
            val m = v.roundToInt().coerceIn(-2048, 2047) and 0x0FFF
            val raw = m // | (0 shl 12)
            val lo = (raw and 0xFF).toByte()
            val hi = ((raw ushr 8) and 0xFF).toByte()
            return byteArrayOf(lo, hi)
        }

        private fun sendOpsAck(success: Boolean) {
            // nRF Toolbox expects CGM Specific Ops Control Point Indication:
            // OpCode = 28 (0x1C) Response Code, Operand: RequestOpCode(26=Start Session 0x1A), Response(1=Success/..)
            val payload = byteArrayOf(0x1C, 0x1A.toByte(), if (success) 0x01 else 0x04)
            if (racpIndicateEnabled) {
                serverConnections.values.forEach { it.sendIndicationFor(opsCharacteristic, payload) }
            } else {
                serverConnections.values.forEach { it.sendIndicationFor(opsCharacteristic, payload) }
            }
            addLog("TX OPS_ACK ok=${success}")
        }

        override fun log(priority: Int, message: String) {
            if (BuildConfig.DEBUG || priority == Log.ERROR) {
                Log.println(priority, TAG, message)
            }
        }

        override fun initializeServer(): List<BluetoothGattService> {
            setServerObserver(this)

            // NOTE: Write handlers will be bound via platform callback in a subsequent step if supported

            // Initialize CGM Feature/Status/Session values for READ
            // Feature: minimal features only (no E2E-CRC). Keep 0 for compatibility.
            featureCharacteristic.value = byteArrayOf(0x00, 0x00, 0x00, 0x00)

            // Status: zeroed (no alarms)
            statusCharacteristic.value = byteArrayOf(0x00, 0x00, 0x00, 0x00)

            // Session Start Time: Date Time (7B) + Time Zone (1B) + DST Offset (1B) = 9 bytes
            run {
                val cal = java.util.Calendar.getInstance()
                val year = cal.get(java.util.Calendar.YEAR)
                val month = cal.get(java.util.Calendar.MONTH) + 1
                val day = cal.get(java.util.Calendar.DAY_OF_MONTH)
                val hour = cal.get(java.util.Calendar.HOUR_OF_DAY)
                val min = cal.get(java.util.Calendar.MINUTE)
                val sec = cal.get(java.util.Calendar.SECOND)
                sessionStartMs = cal.timeInMillis
                seqCounter = 0
                val tzQuarterHours = 0 // UTC offset * 4 (0 = UTC)
                val dstOffset = 0 // standard time
                sessionStartCharacteristic.value = byteArrayOf(
                    (year and 0xFF).toByte(), ((year ushr 8) and 0xFF).toByte(),
                    month.toByte(), day.toByte(), hour.toByte(), min.toByte(), sec.toByte(),
                    tzQuarterHours.toByte(), dstOffset.toByte()
                )
            }

            // Session Run Time: minutes (uint16) — start at 0
            sessionRunCharacteristic.value = byteArrayOf(0x00, 0x00)

            // start simple simulation timers
            val handler = android.os.Handler(context.mainLooper)
            // 1) 1분 주기: 50~230 범위, 반등폭 1~3, 일 1회 스펙아웃 + Session Run Time 증가
            val r = object : Runnable {
                override fun run() {
                    try {
                        val cal = java.util.Calendar.getInstance()
                        val ymd = cal.get(java.util.Calendar.YEAR)*10000 + (cal.get(java.util.Calendar.MONTH)+1)*100 + cal.get(java.util.Calendar.DAY_OF_MONTH)
                        val next = if (lastSpecYmd != ymd) {
                            lastSpecYmd = ymd
                            if (java.util.Random().nextBoolean()) 231 + java.util.Random().nextInt(15) else 40 + java.util.Random().nextInt(10)
                        } else {
                            val step = 1 + java.util.Random().nextInt(3)
                            val dir = if (java.util.Random().nextBoolean()) 1 else -1
                            (simValue + dir * step).coerceAtLeast(50).coerceAtMost(230)
                        }
                        simValue = next
                        notifyMeasurement(simValue)
                        // update Session Run Time (minutes)
                        val runMin = (((System.currentTimeMillis() - sessionStartMs) / 60000L).coerceAtLeast(0)).toInt()
                        sessionRunCharacteristic.value = byteArrayOf((runMin and 0xFF).toByte(), ((runMin ushr 8) and 0xFF).toByte())
                    } catch (_: Throwable) {}
                    handler.postDelayed(this, 60_000) // 1분 주기
                }
            }
            handler.postDelayed(r, 5_000)

            // 2) 10초 주기: 80~250 랜덤 데이터
            val r10 = object : Runnable {
                override fun run() {
                    try {
                        val v = 80 + java.util.Random().nextInt(171) // 80..250
                        sendMeasurement(v, true) // store in queue every 10s
                    } catch (_: Throwable) {}
                    handler.postDelayed(this, 10_000)
                    next10At = System.currentTimeMillis() + 10_000
                }
            }
            handler.postDelayed(r10, 10_000)
            next10At = System.currentTimeMillis() + 10_000

            return myGattServices
        }

        override fun onServerReady() {
            log(Log.INFO, "Gatt server ready")
        }

        override fun onDeviceConnectedToServer(device: BluetoothDevice) {
            log(Log.DEBUG, "Device connected ${device.address}")
            addLog("CONNECTED ${device.address}")

            // A new device connected to the phone. Connect back to it, so it could be used
            // both as server and client. Even if client mode will not be used, currently this is
            // required for the server-only use.
            serverConnections[device.address] = ServerConnection().apply {
                useServer(this@ServerManager)
                connect(device).enqueue()
            }
        }

        override fun onDeviceDisconnectedFromServer(device: BluetoothDevice) {
            log(Log.DEBUG, "Device disconnected ${device.address}")
            addLog("DISCONNECTED ${device.address}")

            // The device has disconnected. Forget it and close.
            serverConnections.remove(device.address)?.close()
        }

        fun getLogs(): List<String> {
            synchronized(logs) {
                val out: java.util.ArrayList<String> = java.util.ArrayList<String>()
                out.addAll(logs)
                return out
            }
        }

        /*
         * Manages the state of an individual server connection (there can be many of these)
         */
        inner class ServerConnection : BleManager(context) {
            override fun getGattCallback(): BleManagerGattCallback {
                return object : BleManagerGattCallback() {
                    override fun initialize() {
                        // Bind write callbacks to server characteristics
                        setWriteCallback(opsCharacteristic).with { device, data ->
                            val v: ByteArray? = data.value
                            addLog("RX OPS len=${v?.size ?: 0}")
                            // minimal: treat as Start Session and ACK
                            sendOpsAck(true)
                        }
                        setWriteCallback(racpCharacteristic).with { device, data ->
                            handleRacpWrite(data.value)
                        }

                        // Observe CCCD changes for Measurement (Notify) and RACP (Indicate)
                        val measCccd = measCharacteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                        val racpCccd = racpCharacteristic.getDescriptor(UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
                        setWriteCallback(measCccd).with { _, data ->
                            val v = data.value
                            val on = v != null && v.size >= 2 && v[0] == 0x01.toByte() && v[1] == 0x00.toByte()
                            measNotifyEnabled = on
                            addLog("CCCD MEAS notify=${on}")
                        }
                        setWriteCallback(racpCccd).with { _, data ->
                            val v = data.value
                            val on = v != null && v.size >= 2 && v[0] == 0x02.toByte() && v[1] == 0x00.toByte()
                            racpIndicateEnabled = on
                            addLog("CCCD RACP indicate=${on}")
                        }
                    }
                    override fun isRequiredServiceSupported(gatt: BluetoothGatt): Boolean = true
                    override fun onServicesInvalidated() { /* no-op */ }
                }
            }

            fun sendNotificationFor(characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                sendNotification(characteristic, value).enqueue()
            }

            fun sendIndicationFor(characteristic: BluetoothGattCharacteristic, value: ByteArray) {
                sendIndication(characteristic, value).enqueue()
            }

            override fun log(priority: Int, message: String) {
                this@ServerManager.log(priority, message)
            }
        }

        

        private fun handleRacpWrite(value: ByteArray?) {
            if (value == null || value.size < 2) {
                sendRacpResponseCode(0x00, 0x04) // invalid operand
                return
            }
            val op = value[0].toInt() and 0xFF
            val operator = value[1].toInt() and 0xFF
            addLog("RX RACP op=${op} operator=${operator}")
            when (op) {
                0x01 -> { // Report Stored Records
                    if (operator != 0x01) { // All records only
                        sendRacpResponseCode(0x01, 0x03) // operator not supported
                        return
                    }
                    // snapshot list
                    val list = java.util.ArrayList<StoredRecord>()
                    synchronized(records) { list.addAll(records) }
                    // support operator >= sequence filter (greater or equal)
                    if (value.size >= 5 && operator == 0x05 && value[2].toInt() == 0x01) { // Filter Type = Sequence Number
                        val minSeq = ((value[4].toInt() and 0xFF) shl 8) or (value[3].toInt() and 0xFF)
                        val filtered = list.filter { it.seq >= minSeq }
                        postReportList(filtered.map { it.payload })
                        return
                    }
                    // default: All stored
                    postReportList(list.map { it.payload })
                    return
                }
                0x04 -> { // Report Number of Stored Records
                    val cnt: Int = synchronized(records) {
                        if (operator == 0x01) {
                            records.size
                        } else if (value.size >= 5 && operator == 0x05 && value[2].toInt() == 0x01) {
                            val minSeq = ((value[4].toInt() and 0xFF) shl 8) or (value[3].toInt() and 0xFF)
                            records.count { it.seq >= minSeq }
                        } else {
                            -1
                        }
                    }
                    if (cnt < 0) {
                        sendRacpResponseCode(0x04, 0x03)
                        return
                    }
                    val resp = byteArrayOf(0x05, 0x00, (cnt and 0xFF).toByte(), ((cnt ushr 8) and 0xFF).toByte())
            serverConnections.values.forEach { it.sendIndicationFor(racpCharacteristic, resp) }
                    addLog("TX RACP NUM cnt=${cnt}")
                }
                0x03 -> { // Abort
                    racpAbort = true
                    sendRacpResponseCode(0x03, 0x01) // success
                    addLog("RACP ABORT requested")
                }
                0x02 -> { // Delete Stored Records
                    if (operator != 0x01) {
                        sendRacpResponseCode(0x02, 0x03)
                        return
                    }
                    synchronized(records) { records.clear() }
                    sendRacpResponseCode(0x02, 0x01)
                    addLog("RACP DELETE all")
                }
                else -> {
                    // OpCode Not Supported
                    sendRacpResponseCode(op, 0x02)
                }
            }
        }

        private fun postNextRacpPacket(requestedOp: Int) {
            if (racpAbort) {
                racpSending = false
                sendRacpResponseCode(requestedOp, 0x01) // success (aborted)
                addLog("RACP REPORT aborted at idx=${racpSendIdx}")
                return
            }
            if (racpSendIdx >= racpSendList.size) {
                racpSending = false
                sendRacpResponseCode(requestedOp, 0x01) // success
                addLog("RACP REPORT done count=${racpSendList.size}")
                return
            }
            val payload = racpSendList[racpSendIdx++]
            serverConnections.values.forEach { it.sendNotificationFor(measCharacteristic, payload) }
            addLog("TX MEAS (RACP) idx=${racpSendIdx}")
            mainHandler.postDelayed({ postNextRacpPacket(requestedOp) }, 40)
        }

        private fun postReportList(list: List<ByteArray>) {
            if (list.isEmpty()) {
                sendRacpResponseCode(0x01, 0x01)
                return
            }
            if (racpSending) racpAbort = true
            racpSending = true
            racpAbort = false
            racpSendList = java.util.ArrayList(list)
            racpSendIdx = 0
            addLog("RACP REPORT start count=${list.size}")
            postNextRacpPacket(requestedOp = 0x01)
        }

        private fun sendRacpResponseCode(requestedOp: Int, status: Int) {
            val resp = byteArrayOf(0x06, 0x00, requestedOp.toByte(), status.toByte())
            serverConnections.values.forEach { it.sendIndicationFor(racpCharacteristic, resp) }
            addLog("TX RACP RESP req=${requestedOp} status=${status}")
        }
    }

    object CgmsProfile {
        val SERVICE_CGMS: UUID = UUID.fromString("0000181F-0000-1000-8000-00805F9B34FB")
        val CHAR_MEASUREMENT: UUID = UUID.fromString("00002AA7-0000-1000-8000-00805F9B34FB")
        val CHAR_FEATURE: UUID = UUID.fromString("00002AA8-0000-1000-8000-00805F9B34FB")
        val CHAR_STATUS: UUID = UUID.fromString("00002AA9-0000-1000-8000-00805F9B34FB")
        val CHAR_SESSION_START_TIME: UUID = UUID.fromString("00002AAA-0000-1000-8000-00805F9B34FB")
        val CHAR_SESSION_RUN_TIME: UUID = UUID.fromString("00002AAB-0000-1000-8000-00805F9B34FB")
        val CHAR_OPS_CONTROL: UUID = UUID.fromString("00002AAC-0000-1000-8000-00805F9B34FB")
        val CHAR_RACP: UUID = UUID.fromString("00002A52-0000-1000-8000-00805F9B34FB")
    }
}
