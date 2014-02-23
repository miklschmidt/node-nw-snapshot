gulp   = require 'gulp'
coffee = require 'gulp-coffee'
exec   = require('child_process').exec
path   = require 'path'

gulp.task 'compile', ->
	gulp.src './src/*.coffee'
	.pipe coffee()
	.pipe gulp.dest './lib'

	gulp.src './src/*.js'
	.pipe gulp.dest './lib'

gulp.task 'test', ['compile'], ->
	mochaPath = path.join __dirname, 'node_modules', '.bin', 'mocha'
	testPath = path.join 'test', 'setup.coffee'
	if process.platform.match(/^Windows/)
		mochaPath = 'mocha'
	cmd = "#{mochaPath} --compilers coffee:coffee-script/register -R spec #{testPath}"
	proc = exec cmd, (err) ->
	proc.stdout.pipe process.stdout
	proc.stderr.pipe process.stderr

gulp.task 'prepublish', ['compile', 'test'], ->

gulp.task 'test-nwsnapshot', ['compile'], ->
	mochaPath = path.join __dirname, 'node_modules', '.bin', 'mocha'
	testPath = path.join 'test', 'nwsnapshot.coffee'
	if process.platform.match(/^win/)
		mochaPath = 'mocha'
	cmd = "#{mochaPath} --compilers coffee:coffee-script/register -R spec #{testPath}"
	proc = exec cmd, (err) ->
	proc.stdout.pipe process.stdout
	proc.stderr.pipe process.stderr