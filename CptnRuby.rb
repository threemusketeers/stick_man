# Basically, the tutorial game taken to a jump'n'run perspective.

# Shows how to
#  * implement jumping/gravity
#  * implement scrolling using Window#translate
#  * implement a simple tile-based map
#  * load levels from primitive text files

# Some exercises, starting at the real basics:
#  0) understand the existing code!
# As shown in the tutorial:
#  1) change it use Gosu's Z-ordering
#  2) add gamepad support
#  3) add a score as in the tutorial game
#  4) similarly, add sound effects for various events
# Exploring this game's code and Gosu:
#  5) make the player wider, so he doesn't fall off edges as easily
#  6) add background music (check if playing in Window#update to implement 
#     looping)
#  7) implement parallax scrolling for the star background!
# Getting tricky:
#  8) optimize Map#draw so only tiles on screen are drawn (needs modulo, a pen
#     and paper to figure out)
#  9) add loading of next level when all gems are collected
# ...Enemies, a more sophisticated object system, weapons, title and credits
# screens...

require 'rubygems'
require 'gosu'
include Gosu

module Tiles
  Grass = 0
  Earth = 1
end

class Collectible
  attr_reader :x, :y, :points

  def initialize(x, y)
    @x, @y = x, y
  end
  
  def touching?(x,y)
    (self.x - x).abs < 50 and (self.y - y).abs < 50
  end
  
  def draw
    # Draw, slowly rotating
    image.draw_rot(@x, @y, 0, 25 * Math.sin(milliseconds / 133.7))
  end
  
  def image
    self.class.image
  end
end

class RubyGem < Collectible
  def initialize(x, y)
    super
    @points = 3
  end
  
  def draw
    # Draw, slowly rotating
    image.draw_rot(@x, @y, 0, 25 * Math.sin(milliseconds / 133.7))
  end
  
  def self.image
    @gem_img ||= Image.new($window, "media/CptnRuby Gem.png", false)
  end
end

class Heart < Collectible
  def initialize(x, y)
    super
    @points = 15
  end
  
  def draw
    # Draw, slowly rotating
    image.draw_rot(@x, @y, 0, 25 * Math.sin(-1 * milliseconds / 133.7))
  end
  
  def self.image
    @gem_img ||= Image.new($window, "media/CptnRuby Heart.png", false)
  end
end

class Monster
  attr_reader :x, :y
  def initialize(x, y)
    @x, @y = x, y
  end
  
  def touching?(x,y)
    (self.x - x).abs < 50 and (self.y - y).abs < 50
  end
  
  def draw
    # Draw, slowly rotating
    image.draw(@x-50, @y-50, 0)
  end
  
  def image
    self.class.image
  end
  
  def touching?(cptn)
    # puts [[x, cptn.x], [y, cptn.y]].inspect
    (self.x - cptn.x).abs < 50 and (self.y - cptn.y).abs < 50
  end
  

  def self.image
    @gem_img ||= Image.new($window, "media/skeleton.png", false)
  end
end

# Player class.
class CptnRuby
  attr_reader :x, :y
  attr_reader :score, :lives

  def initialize(window, x, y)
    @x, @y = x, y
    @dir = :left
    @vy = 0 # Vertical velocity
    @map = window.map
    # Load all animation frames
    @standing, @walk1, @walk2, @jump =
      *Image.load_tiles(window, "media/CptnRuby.png", 50, 50, false)
    # This always points to the frame that is currently drawn.
    # This is set in update, and used in draw.
    @cur_image = @standing   
    @score = 0
    @lives = 5
     
  end

  def die
    @lives -= 1
    sleep(2)
    @x, @y = 400, 100
    draw
  end
  def draw
    # Flip vertically when facing to the left.
    if @dir == :left then
      offs_x = -25
      factor = 1.0
    else
      offs_x = 25
      factor = -1.0
    end
    @cur_image.draw(@x + offs_x, @y - 49, 0, factor, 1.0)
    # puts [@x, @y].inspect
  end
  
  # Could the object be placed at x + offs_x/y + offs_y without being stuck?
  def would_fit(offs_x, offs_y)
    # Check at the center/top and center/bottom for map collisions
    not @map.solid?(@x + offs_x, @y + offs_y) and
      not @map.solid?(@x + offs_x, @y + offs_y - 45)
  end
  
  def update(move_x)
    # Select image depending on action
    if (move_x == 0)
      @cur_image = @standing
    else
      @cur_image = (milliseconds / 175 % 2 == 0) ? @walk1 : @walk2
    end
    if (@vy < 0)
      @cur_image = @jump
    end
    
    # Directional walking, horizontal movement
    if move_x > 0 then
      @dir = :right
      move_x.times { if would_fit(1, 0) then @x += 1 end }
    end
    if move_x < 0 then
      @dir = :left
      (-move_x).times { if would_fit(-1, 0) then @x -= 1 end }
    end

    # Acceleration/gravity
    # By adding 1 each frame, and (ideally) adding vy to y, the player's
    # jumping curve will be the parabole we want it to be.
    @vy += 1
    # Vertical movement
    if @vy > 0 then
      @vy.times { if would_fit(0, 1) then @y += 1 else @vy = 0 end }
    end
    if @vy < 0 then
      (-@vy).times { if would_fit(0, -1) then @y -= 1 else @vy = 0 end }
    end
  end
  
  def try_to_jump
    if @map.solid?(@x, @y + 1) then
      @vy = -20
    end
  end
  
  def collect_gems(gems)
    # Same as in the tutorial game.
    gems.reject! do |c|
      if c.touching?(@x, @y)
        @score += c.points
        true
      else
        false
      end
    end
  end
end

# Map class holds and draws tiles and gems.
class Map
  attr_reader :width, :height, :gems, :monsters
  
  def initialize(window, filename)
    # Load 60x60 tiles, 5px overlap in all four directions.
    @tileset = Image.load_tiles(window, "media/CptnRuby Tileset.png", 60, 60, true)

    @gems = []
    @monsters = []

    lines = File.readlines(filename).map { |line| line.chomp }
    @height = lines.size
    @width = lines[0].size
    @tiles = Array.new(@width) do |x|
      Array.new(@height) do |y|
        case lines[y][x, 1]
        when '"'
          Tiles::Grass
        when '#'
          Tiles::Earth
        when 'x'
          @gems.push(RubyGem.new(x * 50 + 25, y * 50 + 25))
          nil
        when 'h'
          @gems.push(Heart.new(x * 50 + 25, y * 50 + 25))
          nil
        when 'm'
          @monsters.push(Monster.new(x * 50 + 25, y * 50 + 25))
          nil
        else
          nil
        end
      end
    end
  end
  
  def draw
    # Very primitive drawing function:
    # Draws all the tiles, some off-screen, some on-screen.
    @height.times do |y|
      @width.times do |x|
        tile = @tiles[x][y]
        if tile
          # Draw the tile with an offset (tile images have some overlap)
          # Scrolling is implemented here just as in the game objects.
          @tileset[tile].draw(x * 50 - 5, y * 50 - 5, 0)
        end
      end
    end
    @gems.each { |c| c.draw }
    @monsters.each { |c| c.draw }
  end
  
  # Solid at a given pixel position?
  def solid?(x, y)
    y < 0 || @tiles[x / 50][y / 50]
  end
end

class Game < Window
  attr_reader :map

  def initialize
    super(640, 480, false)
    $window = self
    self.caption = "Cptn. Ruby"
    @sky = Image.new(self, "media/Space.png", true)
    @map = Map.new(self, "media/CptnRuby Map.txt")
    @cptn = CptnRuby.new(self, 400, 100)
    # The scrolling position is stored as top left corner of the screen.
    @camera_x = @camera_y = 0
    @font = Gosu::Font.new(self, Gosu::default_font_name, 20)
  end
  def update
    move_x = 0
    move_x -= 5 if button_down? KbLeft
    move_x += 5 if button_down? KbRight
    @cptn.update(move_x)
    @cptn.collect_gems(@map.gems)
    if @map.monsters.any? {|monster| monster.touching? @cptn }
      @cptn.die
    end
    # Scrolling follows player
    @camera_x = [[@cptn.x - 320, 0].max, @map.width * 50 - 640].min
    @camera_y = [[@cptn.y - 240, 0].max, @map.height * 50 - 480].min
  end
  def draw
    @sky.draw 0, 0, 0
    translate(-@camera_x, -@camera_y) do
      @map.draw
      @cptn.draw
    end
    @font.draw("Score: #{@cptn.score}", 10, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
    @font.draw("Lives: #{@cptn.lives}", 500, 10, ZOrder::UI, 1.0, 1.0, 0xffffff00)
  end
  def button_down(id)
    if id == KbUp then @cptn.try_to_jump end
    if id == KbEscape then close end
  end
end

module ZOrder
  Background, Stars, Player, UI = *0..3
end


Game.new.show
