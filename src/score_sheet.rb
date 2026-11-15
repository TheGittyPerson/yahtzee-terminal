# frozen_string_literal: true

require "rainbow/refinement"

using Rainbow

class ScoreSheet
  VALID_FIELDS = %i[aces twos threes fours fives sixes three_of_a_kind
                    four_of_a_kind full_house small_straight large_straight
                    yahtzee chance upper_bonus upper_total lower_total
                    yahtzee_bonus grand_total].freeze
  UPPER_FIELDS = %i[aces twos threes fours fives sixes].freeze
  LOWER_FIELDS = %i[three_of_a_kind four_of_a_kind full_house small_straight
                    large_straight yahtzee chance].freeze
  PLACEHOLDER_MAPPING = {
    aces: "1", twos: "2", threes: "3", fours: "4", fives: "5", sixes: "6",
    three_of_a_kind: "k", four_of_a_kind: "K", full_house: "h",
    small_straight: "s", large_straight: "S", yahtzee: "y", chance: "c",
    upper_bonus: "b", upper_total: "t", lower_total: "T", yahtzee_bonus: "B-",
    grand_total: "g-"
  }.freeze

  attr_accessor :showing_possible_scores

  # @param [Yahtzee]
  def initialize(yahtzee)
    @yahtzee = yahtzee
    @dice_set = yahtzee.dice

    @scores = {
      player1: {
        aces: nil, twos: nil, threes: nil, fours: nil, fives: nil, sixes: nil,
        three_of_a_kind: nil, four_of_a_kind: nil, full_house: nil,
        small_straight: nil, large_straight: nil, yahtzee: nil, chance: nil,
        upper_bonus: nil, yahtzee_bonus: nil,
        upper_total: nil, lower_total: nil, grand_total: nil
      },
      player2: {
        aces: nil, twos: nil, threes: nil, fours: nil, fives: nil, sixes: nil,
        three_of_a_kind: nil, four_of_a_kind: nil, full_house: nil,
        small_straight: nil, large_straight: nil, yahtzee: nil, chance: nil,
        upper_bonus: nil, yahtzee_bonus: nil,
        upper_total: nil, lower_total: nil, grand_total: nil
      }
    }
    @current_player = 1
    @showing_possible_scores = false

    @selected_section = [0, 0]
  end

  def sheet_template
    <<~SHEET
                            ╭─────┬─────╮               ╭─────┬─────╮
      UPPER SECTION         │ P.1 │ P.2 │ LOWER SECTION │ P.1 │ P.2 │
      ╭─────────────────────┼─────┼─────┤ ╭─────────────┼─────┼─────┤
      │ ACES                │ %11 │ %21 │ │ 3 OF A KIND │ %1k │ %2k │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ TWOS                │ %12 │ %22 │ │ 4 OF A KIND │ %1K │ %2K │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ THREES              │ %13 │ %23 │ │ FULL HOUSE  │ %1h │ %2h │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ FOURS               │ %14 │ %24 │ │ SMALL STR8  │ %1s │ %2s │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ FIVES               │ %15 │ %25 │ │ LARGE STR8  │ %1S │ %2S │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ SIXES               │ %16 │ %26 │ │ YAHTZEE     │ %1y │ %2y │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ BONUS (if ≥63, +35) │ %1b │ %2b │ │ CHANCE      │ %1c │ %2c │
      ├─────────────────────┼─────┼─────┤ ├─────────────┼─────┼─────┤
      │ TOTAL               │ %1t │ %2t │ │ TOTAL       │ %1T │ %2T │
      ╰─────────────────────┴─────┴─────╯ ╰─────────────┴─────┴─────╯
      ╭───────────────────────────────────────────────┬──────┬──────╮
      │ YAHTZEE BONUSES (+100 EACH)                   │ %1B- │ %2B- │
      ├───────────────────────────────────────────────┼──────┼──────┤
      │ GRAND TOTAL                                   │ %1g- │ %2g- │
      ╰───────────────────────────────────────────────┴──────┴──────╯
    SHEET
  end

  # @return [Boolean]
  def upper_section_filled?
    !@scores.values_at(*UPPER_FIELDS).include?(nil)
  end

  # @return [Boolean]
  def lower_section_filled?
    !@scores.values_at(*LOWER_FIELDS).include?(nil)
  end

  # Update a field in +@scores+ with a value.
  # @param player_num [Integer]
  # @param field [Symbol]
  # @param value [Integer]
  def update(player_num, field, value)
    unless VALID_FIELDS.include?(field)
      raise ArgumentError, "Invalid field: #{field.inspect}"
    end
    unless (1..2).include? player_num
      raise ArgumentError, "Invalid player number: #{player_num.inspect}"
    end

    @scores[player_num][field] = value
  end

  # Fill a field in the +sheet_template+ with a value and return the resulting
  # string.
  # @param player_num [Integer]
  # @param field [Symbol]
  # @param value [Integer]
  # @return [String]
  def fill_field(sheet_template, player_num, field, value)
    sym = PLACEHOLDER_MAPPING[field]
    placeholder = "%#{player_num}#{sym}"
    sheet_template.gsub(placeholder, value.to_s.rjust(sym[-1] == "-" ? 4 : 3)
                                          .bold)
  end

  # Same as +fill_field+, but uses dim text.
  # @param sheet [String] sheet template.
  # @param player_num [Integer]
  # @param field [Symbol]
  # @param value [Integer]
  # @return [String]
  def fill_possible(sheet, player_num, field, value)
    sym = PLACEHOLDER_MAPPING[field]
    placeholder = "%#{player_num}#{sym}"
    sheet.gsub(placeholder, value.to_s.rjust(sym[-1] == "-" ? 4 : 3).faint)
  end

  # @return [Integer]
  def upper_bonus
    if @scores.values_at(PLACEHOLDER_MAPPING.keys.first(6)).compact.sum >= 63
      35
    else
      0
    end
  end

  # @return [Integer]
  def yahtzee_bonus
    if @scores[:yahtzee] == 50 && @dice_set.combos[:yahtzee] == 50
      @scores[:yahtzee] + 100
    else
      0
    end
  end

  # A string of the scoresheet with all possible scores filled in for the
  # current player.
  # @return [String]
  def possible_scores
    temp_sheet = to_s(remove_remaining_placeholders: false)

    if @yahtzee.turn_started?
      bonuses = { upper_bonus: upper_bonus, yahtzee_bonus: yahtzee_bonus }
      @dice_set.combos.merge(bonuses).each_pair do |key, value|
        temp_sheet = fill_possible(temp_sheet, @current_player, key, value)
      end
    end
    temp_sheet.gsub(/%[1-2][a-zA-Z0-9]-/, "    ")
              .gsub(/%[1-2][a-zA-Z0-9]/, "   ")
  end

  # Set +remove_remaining_placeholders+ to false when using in #possible_scores
  # @param remove_remaining_placeholders [Boolean]
  def to_s(remove_remaining_placeholders: true)
    temp_sheet = sheet_template

    if @yahtzee.turn_started?
      @scores.each_pair do |player, scores|
        scores.each_pair do |key, value|
          next if value.nil?
          temp_sheet = fill_field(temp_sheet, player[-1].to_i, key, value)
        end
      end
    end
    if remove_remaining_placeholders
      temp_sheet = temp_sheet.gsub(/%[1-2][a-zA-Z0-9]-/, "    ")
                             .gsub(/%[1-2][a-zA-Z0-9]/, "   ")
    end
    temp_sheet.gsub("P.1", "\e[1m\e[31mP.1\e[0m")
              .gsub("P.2", "\e[1m\e[34mP.2\e[0m")
  end
end
