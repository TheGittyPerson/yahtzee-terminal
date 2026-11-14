# frozen_string_literal: true

require "rainbow/refinement"

require_relative "die"

using Rainbow

class String
  def win_center
    lines.map { |line| line.chomp.center($stdout.winsize.last) }.join "\n"
  end
end

class DiceSet
  attr_reader :dice, :roles

  # @param [Yahtzee]
  def initialize(yahtzee)
    @yahtzee = yahtzee
    @dice = [Die.new(yahtzee), Die.new(yahtzee),
             Die.new(yahtzee), Die.new(yahtzee), Die.new(yahtzee)]
    @roles = 0
  end

  # Unkeep and reset each die to nil
  def reset
    @dice.each(&:reset)
    @roles = 0
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
    @yahtzee.started = true
  end

  # Tallies die numbers in a Hash.
  # @return [Hash{Integer => Integer}]
  def tally_dice
    die_nums.tally
  end

  # Return a Hash of points awarded for all categories (combos), NOT including
  # bonuses and totals.
  # keys: +:aces+, +:twos+, +:threes+, +:fours+, +:fives+, +:sixes+,
  # +:three_of_a_kind+, +:four_of_a_kind+, +:full_house+, +:small_straight+,
  # +:large_straight+, +:yahtzee+, +:chance+
  # Returns empty hash if the dice have not been rolled yet.
  # @return [Hash{Symbol => Integer}]
  def combos
    return {} unless @yahtzee.started?
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
