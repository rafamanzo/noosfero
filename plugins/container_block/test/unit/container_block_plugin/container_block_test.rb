require 'test_helper'

class ContainerBlockPlugin::ContainerBlockTest < ActiveSupport::TestCase

  def setup
    @block = ContainerBlockPlugin::ContainerBlock.new
    @block.stubs(:owner).returns(Environment.default)
  end

  should 'describe yourself' do
    assert !ContainerBlockPlugin::ContainerBlock.description.blank?
  end

  should 'has a help' do
    assert !@block.help.blank?
  end

  should 'create a box on save' do
    @block.save!
    assert @block.container_box_id
  end

  should 'return created box' do
    @block.save!
    assert @block.container_box
  end

  should 'create new blocks when receive block classes' do
    @block.save!
    assert_difference 'Block.count', 1 do
      @block.block_classes = ['Block']
    end
    assert_equal Block, Block.last.class
  end

  should 'do not create blocks when nothing is passed as block classes' do
    @block.save!
    assert_no_difference 'Block.count' do
      @block.block_classes = []
    end
  end

  should 'do not create blocks when nil is passed as block classes' do
    @block.save!
    assert_no_difference 'Block.count' do
      @block.block_classes = nil
    end
  end

  should 'return a list of blocks associated with the container block' do
    @block.save!
    @block.block_classes = ['Block', 'Block']
    assert_equal [Block, Block], @block.blocks.map(&:class)
  end

  should 'return child width' do
    @block.children_settings = {1 => {:width => 10} }
    @block.save!
    assert_equal 10, @block.child_width(1)
  end

  should 'return nil in width if child do not exists' do
    @block.children_settings = {2 => {:width => 10} }
    @block.save!
    assert_equal nil, @block.child_width(1)
  end

  should 'return nil at layout_template' do
    assert_equal nil, @block.layout_template
  end

  should 'return children blocks that have container_box as box' do
    @block.save!
    child = Block.create!(:box_id => @block.container_box.id)
    assert_equal [child], @block.blocks
  end

  should 'destroy chilrend when container is removed' do
    @block.save!
    child = Block.create!(:box_id => @block.container_box.id)
    @block.destroy
    assert !Block.exists?(child.id)
  end

  should 'destroy box when container is removed' do
    @block.save!
    assert_difference 'Box.count', -1 do
      @block.destroy
    end
  end

end
