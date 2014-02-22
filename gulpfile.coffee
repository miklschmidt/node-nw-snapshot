gulp   = require 'gulp'
coffee = require 'gulp-coffee'
exec   = require('child_process').exec

gulp.task 'compile', ->
	gulp.src './src/*.coffee'
	.pipe coffee()
	.pipe gulp.dest './lib'

	gulp.src './src/*.js'
	.pipe gulp.dest './lib'

gulp.task 'test', ['compile'], ->
	proc = exec "./node_modules/.bin/mocha --compilers coffee:coffee-script/register -R spec test/setup.coffee", (err) ->
	proc.stdout.pipe process.stdout
	proc.stderr.pipe process.stderr

gulp.task 'prepublish', ['compile', 'test'], ->

gulp.task 'test-nwsnapshot', ['compile'], ->
	proc = exec "./node_modules/.bin/mocha --compilers coffee:coffee-script/register -R spec test/nwsnapshot.coffee", (err) ->
	proc.stdout.pipe process.stdout
	proc.stderr.pipe process.stderr