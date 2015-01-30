{exec} = require 'child_process'
path =   require "path"
fs =     require "fs"

wrench = require "wrench"
rimraf = require "rimraf"

retrieveRegistry = require('../../util').retrieveRegistry
logger = null

windowsDrive = /^[A-Za-z]:\\/

_success = ->
  logger.success "New skeleton project successfully created!"
  logger.info "Inside the new project folder, run 'mimosa watch' to build and watch assets."
  logger.info "If the new project has server integration, add a '--server' or '-s' flag to serve assets."

_isSystemPath = (str) ->
  windowsDrive.test(str) or str.indexOf("/") is 0

_isGitHub = (s) ->
  s.indexOf("https://github") is 0 or s.indexOf("git@github") is 0 or s.indexOf("git://github") is 0

_cloneGitHub = (skeletonName, directory) ->
  logger.info "Cloning GitHub repo [[ #{skeletonName} ]] to temp holding directory."

  wrench.rmdirSyncRecursive path.join(process.cwd(), "temp-mimosa-skeleton-holding-directory"), true

  exec "git clone #{skeletonName} temp-mimosa-skeleton-holding-directory", (error, stdout, stderr) ->
    return logger.error "Error cloning git repo: #{stderr}" if error?

    inPath = path.join process.cwd(),"temp-mimosa-skeleton-holding-directory"
    logger.info "Moving cloned repo to  [[ #{directory} ]]."
    _moveDirectoryContents inPath, directory
    logger.info "Cleaning up..."
    _cleanup directory
    _runNPMInstall directory, ->
      rimraf inPath, (err) ->
        if err
          if process.platform is 'win32'
            logger.warn "A known Windows/Mimosa has made the directory at [[ #{inPath} ]] unremoveable. You will want to clean that up.  Apologies!"
            _success()
          else
            logger.error "An error occurred cleaning up the temporary holding directory", err
        else
          _success()

_runNPMInstall = (directory, cb) ->
  currentDir = process.cwd()
  process.chdir directory

  # if no packagejson, no need for npm install
  packageJSON = path.join directory, "package.json"
  if !fs.existsSync(packageJSON)
    return cb()

  logger.info "Running npm install inside project directory..."
  exec "npm install", (err, sout, serr) ->
    if err
      logger.error err
    else
      console.log sout

    if logger.isDebug()
      logger.debug "Node module install sout: #{sout}"
      logger.debug "Node module install serr: #{serr}"

    process.chdir currentDir

    cb()

_moveDirectoryContents = (sourcePath, outPath) ->
  contents = wrench.readdirSyncRecursive(sourcePath).filter (p) ->
    p.indexOf('.git') isnt 0 or p.indexOf('.gitignore') is 0

  unless fs.existsSync outPath
    wrench.mkdirSyncRecursive outPath, 0o0777

  for item in contents
    fullSourcePath = path.join sourcePath, item
    fileStats = fs.statSync fullSourcePath
    fullOutPath = path.join(outPath, item)
    if fileStats.isDirectory()
      logger.debug "Copying directory: [[ #{fullOutPath} ]]"
      wrench.mkdirSyncRecursive fullOutPath, 0o0777
    if fileStats.isFile()
      logger.debug "Copying file: [[ #{fullOutPath} ]]"
      fileContents = fs.readFileSync fullSourcePath
      fs.writeFileSync fullOutPath, fileContents

  _cleanup outPath

_cleanup = (outPath) ->
  wrench.readdirSyncRecursive(outPath).filter (p) ->
    path.basename(p) is '.gitkeep'
  .map (p) ->
    path.join outPath, p
  .forEach (p) ->
    fs.unlinkSync p

newSkeleton = (skeletonName, directory, opts, _logger) ->
  logger = _logger
  if opts.mdebug
    opts.debug = true
    logger.setDebug()
    process.env.DEBUG = true

  directory = if _isSystemPath(directory)
    directory
  else
    path.join process.cwd(), directory

  if _isGitHub(skeletonName)
    _cloneGitHub(skeletonName, directory)
  else if _isSystemPath(skeletonName)
    _moveDirectoryContents skeletonName, directory
    _runNPMInstall directory, ->
      logger.success "Copied local skeleton to [[ #{directory} ]]"
  else
    retrieveRegistry logger, (registry) ->
      skels = registry.skels.filter (s) -> s.name is skeletonName
      if skels.length is 1
        logger.info "Found skeleton in registry"
        _cloneGitHub skels[0].url, directory
      else
        logger.error "Unable to find a skeleton matching name [[ #{skeletonName} ]]"

module.exports = newSkeleton
