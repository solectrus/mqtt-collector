FROM ruby:3.2.1-alpine AS Builder
RUN apk add --no-cache build-base

WORKDIR /mqtt-collector
COPY Gemfile* /mqtt-collector/
RUN bundle config --local frozen 1 && \
    bundle config --local without 'development test' && \
    bundle install -j4 --retry 3 && \
    bundle clean --force

FROM ruby:3.2.1-alpine
LABEL maintainer="mail.loeb@gmail.com"

# Decrease memory usage
ENV MALLOC_ARENA_MAX 2

WORKDIR /mqtt-collector

COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/

COPY . /mqtt-collector/

ENTRYPOINT bundle exec src/main.rb