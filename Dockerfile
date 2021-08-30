FROM jruby:9.2.17.0-jdk11

# Install packages
RUN apt-get update
RUN apt-get install -y build-essential libpq-dev

# Set working directory
RUN mkdir /app
WORKDIR /app

# Bundle and cache Ruby gems
COPY Gemfile* ./
RUN gem update --system
RUN gem install bundler
RUN bundle config set deployment true
RUN bundle config set without development:test
RUN bundle install

# Package and cache UPVS library
COPY lib/upvs lib/upvs
RUN gem install ruby-maven
RUN rmvn -f lib/upvs package

# Cache everything
COPY . .

# Run application by default
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
