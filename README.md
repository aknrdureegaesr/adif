# ADIF

This is ADIF (Amateur Data Interchange Format) Parser/Writer library for Ruby.

ADIF is an open standard for exchange of data between ham radio software packages available from different vendors.

## Installation

This gem is not available via [rubygems.org](https://rubygems.org), but you can easily build it yourself:

    git clone https://github.com/aknrdureegaesr/adif.git
    cd adif
    gem build adif.gemspec
    gem install adif

To use it, add this line to your application's Gemfile:

    gem 'adif'

And then execute:

    $ bundle

## Usage

Not well documented yet, but you are invited to look into the tests at
[./spec/adif_spec.rb](./spec/adif_spec.rb )

## Contributing

0. Have Ruby installed.
1. Fork it and clone your fork.
2. Pull in rspec with `bundle install`
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Change and test (`rspec spec/adif_spec.rb`).
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create a new Pull Request
