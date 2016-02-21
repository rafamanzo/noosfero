class CommentClassificationPlugin::Label < ActiveRecord::Base

  belongs_to :owner, :polymorphic => true

  validates_presence_of :name

  scope :enabled, -> { where enabled: true }

  COLORS = ['red', 'green', 'yellow', 'gray', 'blue']

end
