FROM ruby:2.5

RUN apt-get update && \
    apt-get install -y git && \
    gem install bundler

COPY ./jstreams.gemspec ./Gemfile ./Gemfile.lock /opt/jstreams/

WORKDIR /opt/jstreams

RUN DOCKER_BUILD=true bundle install

COPY . /opt/jstreams
