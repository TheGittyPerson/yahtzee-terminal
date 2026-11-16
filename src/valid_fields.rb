# frozen_string_literal: true

VALID_FIELDS = %i[aces twos threes fours fives sixes three_of_a_kind
                  four_of_a_kind full_house small_straight large_straight
                  yahtzee chance upper_bonus upper_total lower_total
                  yahtzee_bonus grand_total].freeze
UPPER_FIELDS = %i[aces twos threes fours fives sixes].freeze
LOWER_FIELDS = %i[three_of_a_kind four_of_a_kind full_house small_straight
                  large_straight yahtzee chance].freeze

# Check if a field is valid, raise ArgumentError otherwise.
def check_field(field)
  unless VALID_FIELDS.include? field
    raise ArgumentError, "Invalid field: #{field}"
  end
end
