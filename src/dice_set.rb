# frozen_string_literal: true

require "rainbow/refinement"

require_relative "die"
require_relative "valid_fields"

using Rainbow

# Controls the dice and their rolls.
# Keeps track of how many rolls are left in a turn.
class DiceSet
  attr_reader :dice, :roles_left

  # @param [Yahtzee]
  def initialize(yahtzee)
    @yahtzee = yahtzee
    @dice = Array.new(5) { Die.new(@yahtzee) }
    @roles_left = 3
    @turn_started = false
  end

  # Unkeep and reset each die to +nil+.
  def reset
    @dice.each(&:reset)
    @roles_left = 3
    @turn_started = false
  end

  # @return [String]
  def roles_left_indicator
    "\n" + (["    🎲"] * @roles_left).join("\n") + ("\n" * (5 - @roles_left))
  end

  # @return [String]
  def to_s
    Array.new(5, "").each.map.with_index do |line, index|
      @dice.each do |die|
        line += "#{die.to_s.lines[index].chomp} "
      end
      line.strip + roles_left_indicator.lines[index].chomp
    end.join("\n")
  end

  # Array of die numbers.
  # @return [Array<Integer>]
  def die_nums
    @dice.map(&:num)
  end

  def roll
    if @roles_left.zero?
      @yahtzee.add_message "No more roles!"
      return
    end
    return if @dice.map(&:kept?).all?
    @turn_started = true
    @dice.each(&:roll)
    @roles_left -= 1
  end

  def turn_started?
    @turn_started
  end

  # Tallies die numbers in a Hash.
  # @return [Hash{Integer => Integer}]
  def tally_dice
    die_nums.tally
  end

  # Get the score for a combo.
  # Raises an ArgumentError on an invalid field. Returns nil if turn hasn't
  # started yet.
  # @param field [Symbol]
  # @return [Integer]
  def score_for_combo(field)
    check_field field
    combos[field]
  end

  # Return a Hash of points awarded for all categories (combos), NOT including
  # bonuses and totals.
  # keys: +:aces+, +:twos+, +:threes+, +:fours+, +:fives+, +:sixes+,
  # +:three_of_a_kind+, +:four_of_a_kind+, +:full_house+, +:small_straight+,
  # +:large_straight+, +:yahtzee+, +:chance+
  # Returns empty hash if the dice have not been rolled yet (turn has not
  # started yet).
  # @return [Hash{Symbol => Integer}]
  def combos
    return {} unless turn_started?
    {
      aces: die_nums.count { |d| d == 1 },
      twos: die_nums.count { |d| d == 2 } * 2,
      threes: die_nums.count { |d| d == 3 } * 3,
      fours: die_nums.count { |d| d == 4 } * 4,
      fives: die_nums.count { |d| d == 5 } * 5,
      sixes: die_nums.count { |d| d == 6 } * 6,
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

class String
  def win_center
    lines.map { |line| line.chomp.center($stdout.winsize.last) }.join "\n"
  end
end
