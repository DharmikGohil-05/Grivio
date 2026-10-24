require('dotenv').config();
const { setTaskStatus } = require('../src/services/task.service');
setTaskStatus('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000000', 'completed')
  .then((r) => { console.log(r); process.exit(0); })
  .catch((e) => { console.error('ERR:', e.message); process.exit(1); });
