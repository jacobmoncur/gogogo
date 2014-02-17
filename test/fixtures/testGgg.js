// a test ggg file for some mainConfig tests

module.exports = {
  install: '',
  start: 'top-level start',

  targets: {
    test: 'test@test.example.com',
    dev: {
      hosts: ['dev@dev.example.com'],
      start: {
        web: 'dev web',
        worker: 'dev worker'
      }
    },
    prod: {
      hosts: 'prod@prod.example.com',
      start: 'prod-specific command'
    }
  }
}
