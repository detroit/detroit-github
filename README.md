# Detroit GitHub Tool

[Website](http://rubyworks.github.com/detroit-github) /
[Report Issue](http://github.com/rubyworks/detroit-github/issues) /
[Development](http://github.com/rubyworks/detroit-github)

[![Build Status](https://secure.travis-ci.org/rubyworks/detroit-github.png)](http://travis-ci.org/rubyworks/detroit-github) 
[![Gem Version](https://badge.fury.io/rb/detroit-github.png)](http://badge.fury.io/rb/detroit-github) &nbsp; &nbsp;
[![Flattr Me](http://api.flattr.com/button/flattr-badge-large.png)](http://flattr.com/thing/324911/Rubyworks-Ruby-Development-Fund)


## About

The GitHub tool provides services tied to your project's github repository.
Currently it only supports gh-pages publishing from a project's website directory.

When you first run the github tool, it will look for a `web` project directory
(or the directory as specified by the `folder` setting). If it does not exist
it will create it by checking out the reposistory and making `gh-pages` the
sole branch.

Be sure to add `web` (or your configured site directory) in `.gitignore`.


## Install

### With RubyGems

Per the usual gem install process:

    $ gem install detroit-github

Or using Bundler add it to the Gemfile.

    gem "detroit-github"

If using Indexer, make sure `detroit-github` is in your `requirements`.


## Legal

Detroit GitHub &middot;; Copyright (c) 2011 Rubyworks

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

See LICENSE.txt for details.

