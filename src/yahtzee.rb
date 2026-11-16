# frozen_string_literal: true

require 'io/console'
require "rainbow/refinement"

require_relative "dice_set"
require_relative "score_sheet"

using Rainbow

# Main class for the Yahtzee game.
class Yahtzee
  attr_accessor :dice, :sheet
  attr_writer :started

  def initialize
    @dice = DiceSet.new(self)
    @sheet = ScoreSheet.new(self)
    @messages = []
  end

  def run
    new_game
    loop do
      char = $stdin.getch

      if char == "\e"
        next_chars = begin
          $stdin.read_nonblock(3)
        rescue StandardError
          ""
        end

        next unless @dice.turn_started?

        case next_chars
        when "[A"
          @sheet.move_selection :up
        when "[B"
          @sheet.move_selection :down
        when "[C"
          @sheet.move_selection :right
        when "[D"
          @sheet.move_selection :left
        end

      else
        case char&.downcase
        when " "
          @dice.roll
        when "1", "2", "3", "4", "5"
          @dice.dice[char.to_i - 1].toggle_keep
        when "\r"
          next unless @dice.turn_started?
          @sheet.enter_combo
          redraw_screen
          @sheet.next_player
        when "r"
          add_message "Are you sure you want to restart the game?"
          add_message "Press Y to confirm.".bold
          redraw_screen

          char = $stdin.getch&.downcase
          new_game if char == "y"
        when "q"
          puts "\nExiting..."
          return
        end
      end

      redraw_screen
    end
  end


  def header
    out = <<~HEADER

             \e[1m* —— TERMINAL YAHTZEE —— *\e[0m

      SPACE to roll dice, NUMBERS 1-5 to select/deselect dice,
      ARROWS to navigate scoresheet, ENTER to confirm combo,
      Q to quit.

    HEADER
    out.win_center
  end

  def turn_started?
    @dice.turn_started?
  end

  # @param message [Object] Argument is converted to string.
  def add_message(message)
    @messages << message.to_s
  end

  # Basically draws a "frame".
  def redraw_screen
    $stdout.clear_screen
    puts header
    puts @sheet
    puts @dice
    puts
    puts @messages.join("\n")
    @messages.clear
  end

  # Resets sheet and dice, and adds a message for the current player.
  def new_game
    @sheet.reset
    @dice.reset
    add_message(
      "Player #{@sheet.current_player}'s".color(@sheet.current_player_color) +
      " turn!"
    )

    redraw_screen
  end

  # Display final scores and winner, then ask if the players want to play again.
  def finish_game
    add_message "Game over!"
    add_message(
      "FINAL SCORES: #{@sheet.grand_total(1)} - #{@sheet.grand_total(2)}"
    )
    winner = @sheet.winner
    if winner.nil?
      add_message "It's a tie! 🤝"
    else
      add_message "Player #{winner} wins! 👑"
    end
    redraw_screen

    @yahtzee.add_message "Play again?"
    @yahtzee.add_message "Press Y to confirm.".bold
    redraw_screen

    char = $stdin.getch&.downcase
    if char == "y"
      new_game
    else
      puts "\nExiting..."
      exit
    end
  end
end

class String
  def win_center
    lines.map { |line| line.chomp.center($stdout.winsize.last) }.join "\n"
  end
end

if __FILE__ == $PROGRAM_NAME
  yahtzee = Yahtzee.new
  yahtzee.run
end
