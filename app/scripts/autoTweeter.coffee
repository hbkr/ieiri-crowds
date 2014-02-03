config = require "config"
mongoose = require "mongoose"
mongoose.connect "mongodb://#{config.mongodb.host}/#{config.mongodb.db}"
{User} = require "../models/user"

kue = require "kue"
jobs = kue.createQueue()

User.find {"task.auto_tweet":"on" }, (err, results)->
    for user in results
        console.log "add autoTweet job:", user.name, user.task
        jobs.create("autoTweet",
            key:user.twitterToken
            secret:user.twitterTokenSecret
        ).on("complete", ->
            console.log "autoTweet complete"
        ).save()
    mongoose.connection.close()
    process.exit()


