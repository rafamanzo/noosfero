# A Profile is the representation and web-presence of an individual or an
# organization. Every Profile is attached to its Environment of origin,
# which by default is the one returned by Environment:default.
class Profile < ActiveRecord::Base

  PERMISSIONS[:profile] = {
    'edit_profile' => N_('Edit profile'),
    'destroy_profile' => N_('Destroy profile'),
    'manage_memberships' => N_('Manage memberships'),
    'post_content' => N_('Post content'),
    'edit_profile_design' => N_('Edit profile design'),
  }
  
  acts_as_accessible

  acts_as_design

  acts_as_ferret :fields => [ :name ]

  # Valid identifiers must match this format.
  IDENTIFIER_FORMAT = /^[a-z][a-z0-9_]*[a-z0-9]$/

  # These names cannot be used as identifiers for Profiles
  RESERVED_IDENTIFIERS = %w[
  admin
  system
  myprofile
  profile
  cms
  community
  test
  search
  not_found
  ]

  acts_as_taggable

  belongs_to :user

  has_many :domains, :as => :owner
  belongs_to :environment
  
  has_many :role_assignments, :as => :resource

  has_many :articles

  def top_level_articles(reload = false)
    if reload
      @top_level_articles = nil
    end
    @top_level_articles ||= Article.top_level_for(self)
  end
  
  # Sets the identifier for this profile. Raises an exception when called on a
  # existing profile (since profiles cannot be renamed)
  def identifier=(value)
    unless self.new_record?
      raise ArgumentError.new(_('An existing profile cannot be renamed.'))
    end
    self[:identifier] = value
  end

  validates_presence_of :identifier, :name
  validates_format_of :identifier, :with => IDENTIFIER_FORMAT
  validates_exclusion_of :identifier, :in => RESERVED_IDENTIFIERS
  validates_uniqueness_of :identifier

  # creates a new Profile. By default, it is attached to the default
  # Environment (see Environment#default), unless you tell it
  # otherwise
  def initialize(*args)
    super(*args)
    self.environment ||= Environment.default
  end

  # Searches tags by tag or name
  def self.search(term)
    find_tagged_with(term) + find_all_by_name(term)
  end

  def homepage(reload = false)
    # FIXME
    raise 'needs to be implemented'
  end

  # Returns information about the profile's owner that was made public by
  # him/her.
  #
  # The returned value must be an object that responds to a method "summary",
  # which must return an array in the following format:
  #
  #   [
  #     [ 'First Field', first_field_value ],
  #     [ 'Second Field', second_field_value ],
  #   ]
  #
  # This information shall be used by user interface to present the
  # information.
  #
  # In this class, this method returns nil, what is interpreted as "no
  # information at all". Subclasses must override this method to provide their
  # specific information.
  def info
    nil
  end

  # returns the contact email for this profile. By default returns the the
  # e-mail of the owner user.
  #
  # Subclasses may -- and should -- override this method.
  def contact_email
    self.user ? self.user.email : nil
  end

  # gets recent documents in this profile.
  #
  # +limit+ is the maximum number of documents to be returned. It defaults to
  # 10.
  def recent_documents(limit = 10)
    # FIXME not like this anymore
    raise 'needs to be rewritten'
  end

  def superior_instance
    environment
  end
end
