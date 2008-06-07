module Wink

  require 'rdiscount'
  Markdown = RDiscount

rescue LoadError => boom

  warn 'Could not require rdiscount, using BlueCloth for Markdown processing.'

  require 'bluecloth'
  require 'rubypants'

  class Markdown
    def initialize(text, *options)
      @text = text
      @options = options
      @smart = true if options.include?(:smart)
    end
    def to_html(ignored=nil)
      text = BlueCloth.new(@text).to_html
      text = RubyPants.new(text).to_html if @smart
      text
    end
  end

end
