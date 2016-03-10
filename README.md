SlackAws - SoxHub
========

Slack bot for AWS.

## Installation

Run the following commands to initialize and start the bot:

```
sudo gem install bundler
bundle install
export AWS_ACCESS_KEY_ID=YOUR-ACCESS-KEY
export SLACK_API_TOKEN=YOUR-SLACK-BOT-API-TOKEN
bundle exec puma -p 8000
```


## Commands

### aws help

Get help.

### aws s3

* `aws s3 buckets`: Lists S3 buckets.
* `aws s3 ls [bucket] [N]`: Displays max N objects in an S3 bucket.

### aws opsworks

* `aws ops stack help`: Lists stack commands.
* `aws ops instance help`: Lists instance commands.


## Copyright and License

Copyright (c) 2016, Kevin Jhangiani

Forked from original work by Daniel Doubrovkine, Artsy and [Contributors](CHANGELOG.md).

This project is licensed under the [MIT License](LICENSE.md).
