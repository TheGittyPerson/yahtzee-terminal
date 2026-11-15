# frozen_string_literal: true

require 'io/console'
require "rainbow/refinement"

require_relative "dice_set"
require_relative "score_sheet"

using Rainbow

class String
  def win_center
    lines.map { |line| line.chomp.center($stdout.winsize.last) }.join "\n"
  end
end

class Yahtzee
  attr_accessor :dice, :sheet, :messages
  attr_writer :started

  def initialize
    @dice = DiceSet.new(self)
    @sheet = ScoreSheet.new(self)
    @messages = []
  end

  def header
    out = <<~HEADER

             \e[1m* —— TERMINAL YAHTZEE —— *\e[0m

      SPACE to roll dice, NUMBERS 1-5 to select-deselect dice,
      ARROWS to navigate scoresheet, ENTER to confirm combo,
      Q to quit.

    HEADER
    out.win_center
  end

  def turn_started?
    @dice.turn_started?
  end

  def redraw_screen
    $stdout.clear_screen
    puts header
    puts @sheet.possible_scores
    puts @dice
    puts
    puts @messages.join("\n")
    @messages.clear
  end

  def run
    redraw_screen
    loop do
      char = $stdin.getch
      p char

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
        when "1", "2", "3", "4", "5"
          @dice.dice[char.to_i - 1].toggle_keep
          redraw_screen
        when "\r"
          @sheet.enter_combo
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
