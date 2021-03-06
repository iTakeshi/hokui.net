g = require 'gulp'
$ = do require 'gulp-load-plugins'

fs = require 'fs'
child_process = require 'child_process'
argv = require('yargs').argv
dateFormat = require 'dateformat'

del = require 'del'
bowerFiles = require 'main-bower-files'
sort = require 'sort-stream'
lazypipe = require 'lazypipe'

url = require 'url'
proxy = require 'proxy-middleware'
modRewrite  = require 'connect-modrewrite'
browserSync = require 'browser-sync'

play = require 'play'


sounds =
    error: 'misc/error.mp3'

p = console.log

class Conf
    constructor: ->
        @hash = dateFormat (new Date()), 'yyyymmddhhMMss'
        @src = 'client'
        @static = 'static'
        @bowerDir = (try
            JSON.parse(fs.readFileSync '.bowerrc', 'utf8').directory ? throw 'e'
        catch error
            'bower_components'
        )
        @ngAppName = 'hokuiApp'

        @prod = !!argv.prod
        @dest = if @prod then 'dist' else 'public'
        @minify = !argv.skipmin
        @seeding = !!argv.seed
        @silent = !!argv.nosound

        @watching = false

conf = new Conf()


scripts =
    setupRails: ->
        'bundle exec rake db:dev 1>/dev/null 2>/dev/null'
    startE2ETest: ->
        'protractor protractor.conf.js'
    startRails: ->
        'bundle exec rails s -d'
    stopRails: ->
        'if [ -f "./tmp/pids/server.pid" ]; then kill -QUIT `cat tmp/pids/server.pid`; fi'


onError = (arg)->
    if not conf.silent
        play.sound sounds.error
    console.warn "plugin: #{arg.plugin}"
    console.warn "error: #{arg.message}"
    process.exit 1



g.task 'clean', (cb)->
    if conf.watching
        return cb()

    del [
        "#{conf.dest}/**/*"
        "!#{conf.bowerDir}"
        "!#{conf.bowerDir}/**/*"
    ], cb



g.task 'copy:fonts', ['clean'], ->
    g.src "#{conf.bowerDir}/font-awesome/fonts/**/*"
    .pipe g.dest "#{conf.dest}/fonts/"


g.task 'copy:static', ['clean'], ->
    g.src ["#{conf.static}/**/*", "!#{conf.static}/img/**/*"]
    .pipe g.dest "#{conf.dest}/"

g.task 'copy', ['copy:fonts', 'copy:static']



g.task 'image', ['clean'], ->
    g.src "#{conf.static}/img/**/*"
    .pipe $.if conf.prod, $.imagemin()
    .pipe g.dest "#{conf.dest}/img/"


g.task 'css:vendor', ['clean'], ->
    dest = if conf.prod then "#{conf.dest}/.cache/" else "#{conf.dest}/vendor/"

    g.src "#{conf.src}/vendor/**/*.scss"
    .pipe $.sass
        includePaths: [conf.bowerDir]
    .on 'error', onError
    .pipe $.autoprefixer()

    .pipe $.if conf.prod, $.concat 'vendor.css'

    .pipe g.dest dest



g.task 'css:common', ['clean'], ->
    dest = if conf.prod then "#{conf.dest}/.cache/" else "#{conf.dest}/style/"

    g.src "#{conf.src}/style/**/*.sass"
    .pipe $.sass
        sourceComments: 'normal'
        indentedSyntax: true
    .on 'error', onError
    .pipe $.autoprefixer()
    .pipe g.dest dest


g.task 'css:app:inject', ['clean'], ->
    targetFiles =
    g.src("#{conf.src}/{page,component}/**/*.sass", read: false)
    .pipe sort (a, b)->
        a.path.localeCompare b.path
    g.src "#{conf.src}/app.sass"
    .pipe $.inject(
        targetFiles,
            starttag: '// inject:sass'
            endtag: '// endinject'
            transform: (filePath, file, i, length)->
                filePath = filePath.replace "#{conf.src}/", ''
                return "@import \"#{filePath}\""
            addRootSlash: false
    )
    .on 'error', onError
    .pipe g.dest "#{conf.src}/"


g.task 'css:app', ['clean', 'css:app:inject'], ->
    dest = if conf.prod then "#{conf.dest}/.cache/" else "#{conf.dest}/"

    g.src "#{conf.src}/app.sass"
    .pipe $.sass
        indentedSyntax: true
    .on 'error', onError
    .pipe $.autoprefixer()
    .pipe g.dest dest


g.task 'css', ['css:vendor', 'css:common', 'css:app']


g.task 'css:build', ['css'], (cb)->
    if not conf.prod
        return cb()
    # concat order
    # 1. vendor.css: vendor style
    # 2. common.css: common style
    # 3. app.css: app style

    target = [
        "#{conf.dest}/.cache/vendor.css"
        "#{conf.dest}/.cache/common.css"
        "#{conf.dest}/.cache/app.css"
    ]

    g.src target
    .pipe $.concat "app-#{conf.hash}.css"
    .pipe $.if conf.minify, $.minifyCss()
    .pipe g.dest "#{conf.dest}/"



g.task 'html', ['clean'], ->
    dest = if conf.prod then "#{conf.dest}/.cache/" else "#{conf.dest}/"

    target = [
        "#{conf.src}/**/*.jade"
        "!#{conf.src}/index.jade"
    ]

    minifyAndTemplate = lazypipe()
    .pipe $.minifyHtml,
        spare: true
        empty: true
        conditionals: true
        quotes: true
    .pipe $.angularTemplatecache, 'templates.js',
        module: conf.ngAppName
        root: '/'

    g.src target
    .pipe $.jade pretty: not conf.prod
    .on 'error', onError
    .pipe $.if conf.prod, minifyAndTemplate()
    .pipe g.dest dest


g.task 'html:build', ['html'], (cb)->
    cb()



g.task 'js', ['clean'], ->
    dest = if conf.prod then "#{conf.dest}/.cache/" else "#{conf.dest}/"

    target = [
        "#{conf.src}/core/*.coffee"
        "#{conf.src}/core/**/*.coffee"
        "#{conf.src}/component/*.coffee"
        "#{conf.src}/component/**/*.coffee"
        "#{conf.src}/page/*.coffee"
        "#{conf.src}/page/**/*.coffee"
        "#{conf.src}/config/*.coffee"
        "#{conf.src}/config/**/*.coffee"
        "#{conf.src}/*.coffee"
        "!#{conf.bowerDir}/**/*.coffee"
    ]
    if conf.prod
        target.push "!#{conf.src}/config/development/**/*.coffee"
    else
        target.push "!#{conf.src}/config/production/**/*.coffee"

    if not conf.seeding
        target.push "!#{conf.src}/config/seed/**/*.coffee"

    anotateAndConcat = lazypipe()
        .pipe $.ngAnnotate
        .pipe $.concat, 'app.js'

    g.src target, base: "#{conf.src}/"
    .pipe $.sourcemaps.init()
    .pipe $.coffee
        bare: true
        sourceRoot: ''
    .on 'error', onError

    .pipe $.if conf.prod, anotateAndConcat(), $.sourcemaps.write()
    .pipe g.dest dest


g.task 'bower', ['clean'], (cb)->
    if not conf.prod
        return cb()

    g.src bowerFiles()
    .pipe $.concat 'vendor.js'
    .pipe g.dest "#{conf.dest}/.cache/"


g.task 'js:build', ['js', 'html:build', 'bower'], (cb)->
    if not conf.prod
        return cb()

    # concat order
    # 1. vendor.js: bower js
    # 2. app.js: app script
    # 3. templates.js: templates

    target = [
        "#{conf.dest}/.cache/vendor.js"
        "#{conf.dest}/.cache/app.js"
        "#{conf.dest}/.cache/templates.js"
    ]

    g.src target
    .pipe $.concat "app-#{conf.hash}.js"
    .pipe $.if conf.prod, $.uglify()
    .pipe g.dest "#{conf.dest}/"



g.task 'clean:cache', ['css:build', 'js:build', 'html:build'], (cb)->
    if not conf.prod
        return cb()

    del [
        "#{conf.dest}/.cache"
    ], cb



g.task 'index', ['js:build', 'css:build', 'html:build', 'clean:cache'], ->
    ignorePath = ["#{conf.dest}/"]
    target = ''
    if conf.prod
        target = [
            "#{conf.dest}/*.js"
            "#{conf.dest}/*.css"
        ]
    else
        target = [
            "#{conf.dest}/vendor/**/*.css"
            "#{conf.dest}/style/**/*.css"
            "#{conf.dest}/app.css"

            "#{conf.dest}/core/*.js"
            "#{conf.dest}/core/**/*.js"
            "#{conf.dest}/component/*.js"
            "#{conf.dest}/component/**/*.js"
            "#{conf.dest}/page/*.js"
            "#{conf.dest}/page/**/*.js"
            "#{conf.dest}/config/*.js"
            "#{conf.dest}/config/**/*.js"
            "#{conf.dest}/app.js"
        ]

    g.src "#{conf.src}/index.jade"
    .pipe $.jade pretty: not conf.prod
    .on 'error', onError
    .pipe $.inject g.src(target), ignorePath: ignorePath
    .pipe($.if(conf.prod,
        $.if(conf.minify,
            $.minifyHtml
                spare: true
                empty: true
                conditionals: true
                quotes: true
                comments: true
        ),
        $.inject(g.src(bowerFiles(), base: conf.bowerDir, read: false ),{
            ignorePath: ignorePath
            name: 'bower'
        })))

    .pipe g.dest "#{conf.dest}/"



g.task 'build', [
    'copy'
    'image'
    'html:build'
    'js:build'
    'css:build'
    'clean:cache'
    'index'
]



g.task 'serve', ['build'], ->
    makeProxy = (path)->
        proxyOptions = url.parse "http://localhost:3000#{path}"
        proxyOptions.route = path
        proxy proxyOptions

    browserSync
        port: 9000
        notify: false
        open: false
        server:
            baseDir: "#{conf.dest}/"
            middleware: [
                makeProxy '/api/'
            ,
                makeProxy '/contents/'
            ,
                modRewrite [
                    '(.+)/$ $1 [R]'
                    '^(.+)/\\?(.+)$ $1?$2 [R]'
                    '!\\.\\w+$ /index.html [L]'
                ]
            ]



g.task 'watch:css:vendor', ['css:vendor'], ->
    browserSync.reload()
g.task 'watch:css:common', ['css:common'], ->
    browserSync.reload()
g.task 'watch:css:app', ['css:app'], ->
    browserSync.reload()
g.task 'watch:js', ['js'], ->
    browserSync.reload()
g.task 'watch:html', ['html'], ->
    browserSync.reload()
g.task 'watch:index', ['index'], ->
    browserSync.reload()


g.task 'watch', ['build', 'serve'], (cb)->
    if conf.prod
        return cb()
    conf.watching = true
    g.watch "#{conf.src}/vendor/**/*.{sass,scss}", ['watch:css:vendor']
    g.watch "#{conf.src}/style/**/*.{sass,scss}", ['watch:css:common']
    g.watch "#{conf.src}/{page,component}/**/*.{sass,scss}", ['watch:css:app']
    g.watch "#{conf.src}/**/*.coffee", ['watch:js']
    g.watch "#{conf.src}/{page,core,component}/**/*.jade", ['watch:html']
    g.watch "#{conf.src}/index.jade", ['watch:index']



g.task 'rails:setup', $.shell.task [
    scripts.setupRails()
]

g.task 'rails:stop', $.shell.task [
    scripts.stopRails()
]

g.task 'rails', ['rails:stop'], (cb)->
    $.util.log $.util.colors.magenta 'Booting Rails server..'
    child_process.exec scripts.startRails(), (err, stdout, stderr)->
        $.util.log $.util.colors.magenta 'Rails server is booted!'
        cb()

    process.on 'SIGINT', ->
        child_process.exec scripts.stopRails(), (err, stdout, stderr)->
            $.util.log $.util.colors.magenta 'Stop Rails server'
            process.exit()


g.task 'e2e', $.shell.task [
    scripts.startE2ETest()
]


g.task 'run-e2e', ['serve', 'rails:setup', 'rails'], ->
    $.shell.task([
        scripts.startE2ETest()
        scripts.stopRails()
    ])()
    .on 'error', ->
        process.exit 1
    .on 'end', ->
        process.exit 0


g.task 'default', ['watch', 'rails']
