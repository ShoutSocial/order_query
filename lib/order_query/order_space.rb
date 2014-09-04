require 'order_query/order_condition'
module OrderQuery
  # Combine order specification with a scope
  class OrderSpace
    attr_reader :conditions

    # @param [ActiveRecord::Relation] scope
    # @param [Array<Array<Symbol,String>>] order_spec
    def initialize(scope, order_spec)
      @scope = scope
      @conditions = order_spec.map { |spec| OrderCondition.new(scope, spec) }
    end

    # @return [ActiveRecord::Relation]
    def scope
      @scope.order(order_by_sql)
    end

    # @return [ActiveRecord::Relation]
    def reverse_scope
      @scope.order(order_by_reverse_sql)
    end

    SORT_DIRECTIONS = %i(asc desc).freeze

    # @return [String]
    def sort_direction_sql(direction)
      if SORT_DIRECTIONS.include?(direction)
        direction.to_s.upcase.freeze
      else
        raise ArgumentError.new("sort direction must be in #{SORT_DIRECTIONS.map(&:inspect).join(', ')}, is #{direction.inspect}")
      end
    end

    # @return [Array<String>]
    def order_by_sql_clauses
      conditions.map { |cond|
        case order_spec = cond.order
          when Symbol
            "#{cond.col_name_sql} #{sort_direction_sql order_spec}".freeze
          when Enumerable
            order_spec.map { |v|
              "#{cond.col_name_sql}=#{@scope.connection.quote v} #{cond.order_order.to_s.upcase}"
            }.join(', ').freeze
          else
            raise ArgumentError.new("Invalid order #{order_spec.inspect} (#{cond.inspect})")
        end
      }
    end

    # @return [Array<String>]
    def order_by_reverse_sql_clauses
      swap = {'DESC' => 'ASC', 'ASC' => 'DESC'}
      order_by_sql_clauses.map { |s|
        s.gsub(/DESC|ASC/) { |m| swap[m] }
      }
    end

    # @return [String]
    def order_by_reverse_sql
      join_order_by_clauses order_by_reverse_sql_clauses
    end

    # @return [String]
    def order_by_sql
      join_order_by_clauses order_by_sql_clauses
    end

    # @param [Array<String>] clauses
    def join_order_by_clauses(clauses)
      clauses.join(', ').freeze
    end
  end
end
