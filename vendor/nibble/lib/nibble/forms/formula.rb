require "strscan"

module Nibble
  module Forms
    # Must parse and count exactly as frontend/nibble/formula.ts does: the server's value is the one stored.
    class Formula
      Error = Class.new(Nibble::Error)

      FUNCTIONS = { "round" => 1..2, "min" => 2..2, "max" => 2..2 }.freeze
      NUMBER = /\A-?\d+(?:\.\d+)?\z/
      SPACE = /[ \t\r\n]*/
      MAX_DIGITS = 15

      attr_reader :references

      def self.number(raw)
        case raw
        when true then 1.0
        when Numeric then raw.to_f
        when String then raw.strip.match?(NUMBER) ? raw.strip.to_f : 0.0
        else 0.0
        end
      end

      def self.round(value, digits)
        scale = 10.0**digits.to_f.truncate.clamp(0, MAX_DIGITS)
        scaled = value * scale
        scaled.finite? ? scaled.round / scale : nil
      end

      def initialize(source)
        @tokens = tokenize(source.to_s)
        @position = 0
        @references = []
        @tree = expression
        raise Error, "unexpected '#{@tokens[@position][1]}'" if @tokens[@position]

        @references.uniq!
      end

      def evaluate(values, decimals: nil)
        result = value(@tree, values.to_h.stringify_keys)
        result = self.class.round(result, decimals) if result && decimals
        return nil if result.nil?
        return 0 if result.zero?

        result == result.round && result.abs < 1e15 ? result.to_i : result
      end

      private

      def tokenize(source)
        scanner = StringScanner.new(source)
        tokens = []
        until scanner.skip(SPACE) && scanner.eos?
          tokens << if scanner.scan(/\d+(?:\.\d+)?/) then [ :number, scanner.matched.to_f ]
          elsif scanner.scan(/\{([a-z][a-z0-9_]*)\}/) then [ :ref, scanner[1] ]
          elsif scanner.scan(/[a-z]+/) then [ :name, scanner.matched ]
          elsif scanner.scan(%r{[-+*/(),]}) then [ :op, scanner.matched ]
          else raise Error, "can't read '#{scanner.rest.first(10)}'"
          end
        end
        tokens
      end

      def operator = (token = @tokens[@position]) && token[0] == :op ? token[1] : nil
      def advance = @tokens[@position].tap { @position += 1 }
      def accept(op) = operator == op && advance
      def expect(op) = accept(op) || raise(Error, "expected '#{op}'")

      def expression
        node = term
        node = [ advance[1], node, term ] while %w[+ -].include?(operator)
        node
      end

      def term
        node = unary
        node = [ advance[1], node, unary ] while %w[* /].include?(operator)
        node
      end

      def unary = accept("-") ? [ :neg, unary ] : primary

      def primary
        kind, token = advance
        case kind
        when :number then [ :number, token ]
        when :ref
          @references << token
          [ :ref, token ]
        when :name then call(token)
        when :op
          raise Error, "unexpected '#{token}'" unless token == "("

          expression.tap { expect(")") }
        else raise Error, "the formula ends too soon"
        end
      end

      def call(name)
        arity = FUNCTIONS[name] or raise Error, "'#{name}' isn't a function: use round, min or max"
        expect("(")
        args = [ expression ]
        args << expression while accept(",")
        expect(")")
        raise Error, "#{name} takes #{arity.minmax.uniq.join(' or ')} values" unless arity.cover?(args.size)

        [ :call, name, args ]
      end

      def value(node, values)
        kind, *rest = node
        case kind
        when :number then rest[0]
        when :ref then self.class.number(values[rest[0]])
        when :neg then (inner = value(rest[0], values)) && -inner
        when :call
          args = rest[1].map { |arg| value(arg, values) }
          finite(apply(rest[0], args)) unless args.include?(nil)
        else
          left = value(rest[0], values)
          right = value(rest[1], values)
          finite(left.public_send(kind, right)) unless left.nil? || right.nil? || (kind == "/" && right.zero?)
        end
      end

      def apply(name, args)
        case name
        when "round" then self.class.round(args[0], args[1] || 0)
        when "min" then args.min
        when "max" then args.max
        end
      end

      def finite(number) = number&.finite? ? number : nil
    end
  end
end
