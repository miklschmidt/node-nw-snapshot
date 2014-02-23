gulp   = require 'gulp'
coffee = require 'gulp-coffee'
exec   = require('child_process').exec
path   = require 'path'
mocha  = require 'gulp-mocha'

gulp.task 'compile', ->
	gulp.src './src/*.coffee'
	.pipe coffee()
	.pipe gulp.dest './lib'

	gulp.src './src/*.js'
	.pipe gulp.dest './lib'

gulp.task 'test', ['compile'], ->
	gulp.src './test/setup.coffee'
	.pipe mocha reporter: 'spec'

gulp.task 'prepublish', ['compile', 'test'], ->

gulp.task 'test-nwsnapshot', ['compile'], ->
	gulp.src './test/nwsnapshot.coffee'
	.pipe mocha reporter: 'spec'