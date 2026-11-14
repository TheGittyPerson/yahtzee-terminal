# frozen_string_literal: true

# 14-17th November 2026

require 'io/console'
require "rainbow/refinement"

using Rainbow

class Die
  include Comparable

  attr_reader :num

  def initialize
    @keep = false
    @num = nil
  end

  # @return [String]
  def to_s
    out = case @num
          when 1 then <<~ONE
            ╭────────╮
            │        │
            │   ⬤    │
            │        │
            ╰────────╯
          ONE
          when 2 then <<~TWO
            ╭────────╮
            │ ⬤      │
            │        │
            │     ⬤  │
            ╰────────╯
          TWO
          when 3 then <<~THREE
            ╭────────╮
            │ ⬤      │
            │   ⬤    │
            │     ⬤  │
            ╰────────╯
          THREE
          when 4 then <<~FOUR
            ╭────────╮
            │ ⬤   ⬤  │
            │        │
            │ ⬤   ⬤  │
            ╰────────╯
          FOUR
          when 5 then <<~FIVE
            ╭────────╮
            │ ⬤   ⬤  │
            │   ⬤    │
            │ ⬤   ⬤  │
            ╰────────╯
          FIVE
          when 6 then <<~SIX
            ╭────────╮
            │ ⬤   ⬤  │
            │ ⬤   ⬤  │
            │ ⬤   ⬤  │
            ╰────────╯
          SIX
          else <<~NIL
            ╭────────╮
            │        │
            │   ⭐️   │
            │        │
            ╰────────╯
          NIL
          end
    return out.bold.green if kept?
    out
  end

  # Roles this die, unless it has been kept.
  def roll
    @num = rand 1..6 unless @keep
  end

  def keep
    @keep = true
  end

  def unkeep
    @keep = false
  end

  def reset
    unkeep
    @num = nil
  end

  # @return [Boolean]
  def kept?
    @keep
  end

  # @param other [Die]
  # @return [Integer, nil]
  def <=>(other)
    other.is_a?(Die) ? @num <=> other.num : nil
  end
end

class DiceSet
  attr_reader :dice, :roles

  def initialize
    @dice = [Die.new, Die.new, Die.new, Die.new, Die.new]
    @roles = 0
    @started = false
  end

  # Unkeep and reset each die to nil
  def reset
    @dice.each(&:reset)
    @roles = 0
    @started = false
  end

  # @return [String]
  def to_s
    Array.new(5, "").each.map.with_index do |line, index|
      @dice.each do |die|
        line += "#{die.to_s.lines[index].chomp} "
      end
      line.strip
    end.join("\n")
  end

  # Array of die numbers.
  # @return [Array<Integer>]
  def die_nums
    @dice.map(&:num)
  end

  def roll
    return if @dice.map(&:kept?).all?
    @dice.each(&:roll)
    @roles += 1 unless @roles >= 3
    @started = true
  end

  # Tallies die numbers in a Hash.
  # @return [Hash{Integer => Integer}]
  def tally_dice
    die_nums.tally
  end

  # @return [Boolean]
  def started?
    @started
  end

  # Return a Hash of points awarded for all categories (combos), NOT including
  # bonuses and totals.
  # keys: +:aces+, +:twos+, +:threes+, +:fours+, +:fives+, +:sixes+,
  # +:three_of_a_kind+, +:four_of_a_kind+, +:full_house+, +:small_straight+,
  # +:large_straight+, +:yahtzee+, +:chance+
  # Returns empty hash if the dice have not been rolled yet.
  # @return [Hash{Symbol => Integer}]
  def combos
    return {} unless @started
    {
      aces: @dice.count { |d| d == 1 },
      twos: @dice.count { |d| d == 2 },
      threes: @dice.count { |d| d == 3 },
      fours: @dice.count { |d| d == 4 },
      fives: @dice.count { |d| d == 5 },
      sixes: @dice.count { |d| d == 6 },
      three_of_a_kind: tally_dice.any? { |_, n| n >= 3 } ? die_nums.sum : 0,
      four_of_a_kind: tally_dice.any? { |_, n| n >= 4 } ? die_nums.sum : 0,
      full_house: if tally_dice.values.include?(3) &&
                     tally_dice.values.include?(2)
                    25
                  else
                    0
                  end,
      small_straight: if die_nums.sort.each_cons(2)
                                 .map { |a, b| b - a }.count(1) >= 3
                        30
                      else
                        0
                      end,
      large_straight: if die_nums.sort.each_cons(2)
                                 .map { |a, b| b - a }.count(1) == 4
                        40
                      else
                        0
                      end,
      yahtzee: die_nums.uniq.length == 1 ? 50 : 0,
      chance: die_nums.sum
    }
  end
end

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

  # @param [DiceSet]
  def initialize(dice)
    @dice_set = dice

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
  # @return [Integer]
  def possible_scores
    temp_sheet = sheet_template

    if @dice_set.started?
      bonuses = { upper_bonus: upper_bonus, yahtzee_bonus: yahtzee_bonus }
      @dice_set.combos.merge(bonuses).each_pair do |key, value|
        temp_sheet = fill_possible(temp_sheet, @current_player, key, value)
      end
    else
      temp_sheet.gsub(/%[1-2][a-zA-Z]/, "   ")
                .gsub(/%[1-2][a-zA-Z]-/, "    ")
    end
    temp_sheet
  end

  def to_s
    temp_sheet = sheet_template

    if @dice_set.started?
      @scores.each_pair do |player, scores|
        scores.each_pair do |key, value|
          next if value.nil?
          temp_sheet = fill_field(temp_sheet, player[-1].to_i, key, value)
        end
      end
    else
      temp_sheet.gsub(/%[1-2][a-zA-Z]/, "   ")
                .gsub(/%[1-2][a-zA-Z]-/, "    ")
    end
    temp_sheet
  end
end

class Yahtzee
  def initialize
    @dice = DiceSet.new
    @sheet = ScoreSheet.new(@dice)

    $stdout.winsize = [50, 55]
  end

  def redraw_screen
    $stdout.clear_screen
    puts @sheet.possible_scores
    puts @dice.to_s.center($stdout.winsize.last)
  end

  def run
    redraw_screen
    loop do
      char = $stdin.getch

      if char == "\e"
        next_chars = begin
          $stdin.read_nonblock(3)
        rescue StandardError
          ""
        end

        case next_chars
        when "[A"
          @sheet.select_up
          redraw_screen
        when "[B"
          @sheet.select_down
          redraw_screen
        when "[C"
          @sheet.select_right
          redraw_screen
        when "[D"
          @sheet.select_left
          redraw_screen
        end

      else
        case char&.downcase
        when " "
          @dice.roll
          redraw_screen
        when "q"
          puts "Exiting..."
          return
        end
      end
    end
  end
end


if __FILE__ == $PROGRAM_NAME
  yahtzee = Yahtzee.new
  yahtzee.run
end
