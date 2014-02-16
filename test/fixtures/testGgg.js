// a test ggg file for some mainConfig tests

module.exports = {
  install: '',
  start: {
    web:'top-level web start',
    worker: 'top-level worker start'
  },

  targets: {
    test: 'test@test.example.com',
    dev: {
      hosts: ['dev@dev.example.com'],
      start: 'dev start'
    },
    prod: {
      hosts: 'prod@prod.example.com',
      start: ''
    }
  }
}
