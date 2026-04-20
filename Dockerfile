# EMPECS CGMS Flutter Web — QA용 (BLE 제외, 동일 API as 모바일)
# 빌드: docker build -t empecs-cgms-app-web .
# 로컬: flutter run -d chrome --web-browser-flag "--disable-web-security" (필요 시)

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
