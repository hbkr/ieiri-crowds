config = require "config"
console.log "load config", JSON.stringify config, "\n"

http = require "http"
express = require "express"

RedisStore = require("connect-redis")(express)

passport = require "passport"
TwitterStrategy = require("passport-twitter").Strategy

mongoose = require "mongoose"
mongoose.connect "mongodb://#{config.mongodb.host}/#{config.mongodb.db}"
require "mongoose-pagination"

{User} = require "./models/user"

passport.serializeUser (user, done) ->
    done null, user.uid
passport.deserializeUser (uid, done) ->
    User.findOne {uid: uid}, (err, user) ->
        done err, user
passport.use new TwitterStrategy
    consumerKey: config.twitter.consumerKey
    consumerSecret: config.twitter.consumerSecret
    callbackURL: config.twitter.callbackURL
    , (token, tokenSecret, profile, done) ->
        User.loginTwitter token, tokenSecret, profile, done

app = express()
app.configure ->
    app.set "views", __dirname + '/views'
    app.set "view engine", "jade"
    app.use "/static", express.static 'static'
    app.use express.logger "dev"
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use express.cookieParser("secret", config.cookie.secret)
    app.use express.session
        secret: config.sessionRedis.secret
        cookie: {maxAge: 1000 * 60 * 60 * 24 * 7}
        store: new RedisStore({db: config.sessionRedis.db, prefix: config.sessionRedis.prefix})
    app.use express.csrf()
    app.use (req, res, next) ->
        res.locals.token = req.csrfToken()
        next()
    app.use passport.initialize()
    app.use passport.session()

app.get "/auth/twitter",
    passport.authenticate "twitter"
app.get "/auth/twitter/callback",
    passport.authenticate "twitter",
        successRedirect: "/app/ieiri/join",
        failureRedirect: "/"


app.get "/top", (req, res) ->
    if not req.user?
        res.redirect "/"
    else
        res.send "top"

allowCrossOrigin = (res)->
    res.header 'Access-Control-Allow-Origin', '*'
    res.header 'Access-Control-Allow-Credentials', true
    res.header 'Access-Control-Allow-Methods', 'POST, GET, PUT, DELETE, OPTIONS'
    res.header 'Access-Control-Allow-Headers', 'Content-Type'
# /users?page=1&per_page=15
app.get "/users", (req, res) ->
    allowCrossOrigin res
    page = req.query.page ? "1"
    per_page = req.query.per_page ? "15"
    User.find().paginate page, per_page, (err, results, total) ->
        res.send {users:results, page:page, per_page:per_page, total:total}

app.get "/user", (req, res) ->
    if not req.user?
        res.redirect "/"
    else
        res.send req.user

app.get "/close", (req, res) ->
    res.render "close"

app.get "/ieiri/join", (req, res) ->
    if not req.user?
        res.redirect "/"
    else
        res.render "ieiri", {user:req.user}

app.post "/ieiri/join", (req, res) ->
    console.log req.body
    if req.body.over_20 == "on"
        req.user.updateTwitter req, ()->
            res.render "close"
    else
        res.send "fail"

module.exports = app
if not module.parent
    server = http.createServer(app).listen(3000)
    io = require("socket.io").listen server, {'log level':2}
    app.set "io", io
    require "./socket"
    console.log "app start 3000"
