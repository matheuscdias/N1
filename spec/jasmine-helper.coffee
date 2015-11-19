fs = require 'fs'
{remote} = require 'electron'

module.exports.runSpecSuite = (specSuite, logFile, logErrors=true) ->
  {$, $$} = require '../src/space-pen-extensions'

  window[key] = value for key, value of require './jasmine'

  {TerminalReporter} = require 'jasmine-tagged'

  disableFocusMethods() if process.env.JANKY_SHA1

  TimeReporter = require './time-reporter'
  timeReporter = new TimeReporter()

  logStream = fs.openSync(logFile, 'w') if logFile?
  log = (str) ->
    if logStream?
      fs.writeSync(logStream, str)
    else
      remote.process.stdout.write(str)

  if NylasEnv.getLoadSettings().exitWhenDone
    reporter = new TerminalReporter
      color: true
      print: (str) ->
        log(str)
      onComplete: (runner) ->
        fs.closeSync(logStream) if logStream?
        if process.env.JANKY_SHA1
          grim = require 'grim'
          grim.logDeprecations() if grim.getDeprecationsLength() > 0
        if runner.results().failedCount > 0
          NylasEnv.exit(1)
        else
          NylasEnv.exit(0)
  else
    N1SpecReporter = require './n1-spec-reporter'
    reporter = new N1SpecReporter()

  NylasEnv.initialize()

  # Tests that run under an integration environment need Spectron to be
  # asynchronously setup and connected to the Selenium API before proceeding.
  # Once setup, one can test `NylasEnv.inIntegrationSpecMode()`
  #
  # This safely works regardless if Spectron is loaded.
  NylasEnv.setupSpectron().finally ->
    require specSuite

    jasmineEnv = jasmine.getEnv()
    jasmineEnv.addReporter(reporter)
    jasmineEnv.addReporter(timeReporter)
    jasmineEnv.setIncludedTags([process.platform])

    $('body').append $$ -> @div id: 'jasmine-content'

    jasmineEnv.execute()

disableFocusMethods = ->
  ['fdescribe', 'ffdescribe', 'fffdescribe', 'fit', 'ffit', 'fffit'].forEach (methodName) ->
    focusMethod = window[methodName]
    window[methodName] = (description) ->
      error = new Error('Focused spec is running on CI')
      focusMethod description, -> throw error