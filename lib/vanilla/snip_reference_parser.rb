require "parslet"

module Vanilla
  class SnipReferenceParser
    class Reference
      def initialize(attributes)
        @attributes = attributes
      end
      def snip
        @attributes[:snip]
      end
      def attribute
        @attributes[:attribute]
      end
      def arguments
        @attributes[:arguments] || []
      end
    end

    def parse(string)
      Reference.new(SnipTransform.new.apply(SnipParser.new.parse(string)))
    end

    class SnipParser < Parslet::Parser
      rule(:spaces) { match('\s').repeat(1) }
      rule(:spaces?) { spaces.maybe }
      rule(:comma)  { match(',') }
      rule(:dot)    { str(".") }
      rule(:squote) { str("'") }
      rule(:dquote) { str('"') }
      rule(:escaped_dquote) { str('"') }
      rule(:left_brace) { str("{") }
      rule(:right_brace) { str("}") }

      rule(:word) { match("[a-zA-Z0-9_\\-]").repeat(1) }
      rule(:quotables) { word | comma | spaces }
      rule(:double_quoted_string) do
        dquote >> (quotables | squote).repeat(1).as(:string) >> dquote
      end
      rule(:single_quoted_string) do
        squote >> (quotables | dquote).repeat(1).as(:string) >> squote
      end
      rule(:string) do
        single_quoted_string | double_quoted_string | str("nil").as(:nil) | word.as(:string)
      end
      rule(:symbol) { str(":") >> string }

      rule(:comma_separator) { spaces? >> comma >> spaces? }
      rule(:hash_separator) { spaces? >> str("=>") >> spaces? }
      rule(:named_separator) { spaces? >> str(":") >> spaces? }

      rule(:hash_arg) { (symbol | string).as(:key) >> hash_separator >> string.as(:value) }
      rule(:named_arg) { string.as(:key) >> named_separator >> string.as(:value) }

      rule(:string_arg_list) { (string.as(:string_arg) >> further_string_args.repeat).as(:string_arg_list) }
      rule(:further_string_args) { comma_separator >> string.as(:string_arg) }

      rule(:hash_arg_list) { (hash_arg.as(:hash_arg) >> further_hash_args.repeat).as(:key_value_arg_list) }
      rule(:further_hash_args) { comma_separator >> hash_arg.as(:hash_arg) }

      rule(:named_arg_list) { (named_arg.as(:named_arg) >> further_named_args.repeat).as(:key_value_arg_list) }
      rule(:further_named_args) { comma_separator >> named_arg.as(:named_arg) }

      rule(:arguments) { hash_arg_list | named_arg_list | string_arg_list }
      rule(:snip_part) { string.as(:snip) >> (dot >> string.as(:attribute)).maybe }

      rule(:snip_reference) do
        left_brace >> spaces? >>
          snip_part >> (spaces >> arguments.as(:arguments)).maybe >>
          spaces? >> right_brace
      end

      root(:snip_reference)
    end

    class SnipTransform < Parslet::Transform
      rule(:nil => simple(:x)) { nil }
      rule(:string => simple(:x)) { x.to_s }
      rule(:string_arg => simple(:x)) { x }
      rule(:string_arg_list => simple(:x)) { [x] }
      rule(:string_arg_list => sequence(:x)) { x }

      class Arg
        def initialize(k, v); @k, @v = k, v; end
        def to_h; {@k.to_sym => @v}; end
      end

      rule(:hash_arg => subtree(:x)) { Arg.new(x[:key], x[:value]) }
      rule(:named_arg => subtree(:x)) { Arg.new(x[:key], x[:value]) }
      rule(:key_value_arg_list => simple(:x)) { x.to_h }
      rule(:key_value_arg_list => sequence(:x)) { x.inject({}) { |h, kv| h.merge(kv.to_h) } }
    end
  end
end