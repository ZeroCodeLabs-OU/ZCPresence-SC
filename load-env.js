// load-env.js
require('dotenv').config();

const exec = require('child_process').exec;
const command = process.argv.slice(2).join(' '); // Passes CLI args to Foundry

exec(`forge ${command}`, (err, stdout, stderr) => {
    console.log(stdout);
    console.error(stderr);
    if (err !== null) {
        console.error(`Exec error: ${err}`);
    }
});
