const fs = require("fs");
const path = require("path");

function walkFiles(rootDirAbs) {
  const out = [];
  const stack = [rootDirAbs];
  while (stack.length) {
    const dir = stack.pop();
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const ent of entries) {
      const abs = path.join(dir, ent.name);
      if (ent.isDirectory()) stack.push(abs);
      else if (ent.isFile()) out.push(abs);
    }
  }
  return out;
}

module.exports = { walkFiles };

