require File.dirname(__FILE__) + '/../test_helper'

class ArticleTest < Test::Unit::TestCase

  fixtures :environments

  def setup
    @profile = create_user('testing').person
  end
  attr_reader :profile

  should 'have and require an associated profile' do
    a = Article.new
    a.valid?
    assert a.errors.invalid?(:profile_id)

    a.profile = profile
    a.valid?
    assert !a.errors.invalid?(:profile_id)
  end

  should 'require value for name' do
    a = Article.new
    a.valid?
    assert a.errors.invalid?(:name)

    a.name = 'my article'
    a.valid?
    assert !a.errors.invalid?(:name)
  end

  should 'require value for slug and path if name is filled' do
    a = Article.new(:name => 'test article')
    a.slug = nil
    a.path = nil
    a.valid?
    assert a.errors.invalid?(:slug)
    assert a.errors.invalid?(:path)
  end

  should 'not require value for slug and path if name is blank' do
    a = Article.new
    a.valid?
    assert !a.errors.invalid?(:slug)
    assert !a.errors.invalid?(:path)
  end

  should 'act as versioned' do
    a = Article.create!(:name => 'my article', :body => 'my text', :profile_id => profile.id)
    assert_equal 1, a.versions(true).size
    a.name = 'some other name'
    a.save!
    assert_equal 2, a.versions(true).size
  end

  should 'act as taggable' do
    a = Article.create!(:name => 'my article', :profile_id => profile.id)
    a.tag_list = ['one', 'two']
    tags = a.tag_list.names
    assert tags.include?('one')
    assert tags.include?('two')
  end

  should 'act as filesystem' do
    a = Article.create!(:name => 'my article', :profile_id => profile.id)
    b = a.children.build(:name => 'child article', :profile_id => profile.id)
    b.save!
    assert_equal 'my-article/child-article', b.path

    a = Article.find(a.id);
    a.name = 'another name'
    a.save!

    assert_equal 'another-name/child-article', Article.find(b.id).path
  end

  should 'provide HTML version' do
    profile = create_user('testinguser').person
    a = Article.create!(:name => 'my article', :profile_id => profile.id)
    a.expects(:body).returns('the body of the article')
    assert_equal 'the body of the article', a.to_html
  end

  should 'provide first paragraph of HTML version' do
    profile = create_user('testinguser').person
    a = Article.create!(:name => 'my article', :profile_id => profile.id)
    a.expects(:body).returns('<p>the first paragraph of the article</p> The second paragraph')
    assert_equal '<p>the first paragraph of the article</p>', a.first_paragraph
  end

  should 'inform the icon to be used' do
    assert_equal 'text-html', Article.new.icon_name
  end

  should 'provide a (translatable) description' do
    result = 'the description'

    a = Article.new
    a.expects(:_).returns(result)
    assert_same result, a.mime_type_description
  end

  should 'not accept articles with same slug under the same level' do

    # top level articles first
    profile = create_user('testinguser').person
    a1 = profile.articles.build(:name => 'test')
    a1.save!

    # cannot add another top level article with same slug
    a2 = profile.articles.build(:name => 'test')
    a2.valid?
    assert a2.errors.invalid?(:slug)

    # now create a child of a1
    a3 = profile.articles.build(:name => 'test')
    a3.parent = a1
    a3.valid?
    assert !a3.errors.invalid?(:slug)
    a3.save!

    # cannot add another child of a1 with same slug
    a4 = profile.articles.build(:name => 'test')
    a4.parent = a1
    a4.valid?
    assert a4.errors.invalid?(:slug)
  end

  should 'record who did the last change' do
    a = profile.articles.build(:name => 'test')

    # must be a person
    assert_raise ActiveRecord::AssociationTypeMismatch do
      a.last_changed_by = Profile.new
    end
    assert_nothing_raised do
      a.last_changed_by = Person.new
      a.save!
    end
  end

  should 'search for recent documents' do
    other_profile = create_user('otherpropfile').person

    Article.destroy_all

    first = profile.articles.build(:name => 'first'); first.save!
    second = profile.articles.build(:name => 'second'); second.save!
    third = profile.articles.build(:name => 'third'); third.save!
    fourth = profile.articles.build(:name => 'fourth'); fourth.save!
    fifth = profile.articles.build(:name => 'fifth'); fifth.save!

    other_first = other_profile.articles.build(:name => 'first'); other_first.save!
    
    assert_equal [other_first, fifth, fourth], Article.recent(3)
    assert_equal [other_first, fifth, fourth, third, second, first], Article.recent(6)
  end

  should 'not show private documents as recent' do
    p = create_user('usr1').person
    Article.destroy_all

    first  = p.articles.build(:name => 'first',  :published => true);  first.save!
    second = p.articles.build(:name => 'second', :published => false); second.save!

    assert_equal [ first ], Article.recent(nil)
  end

  should 'not show unpublished documents as recent' do
    p = create_user('usr1').person
    Article.destroy_all

    first  = p.articles.build(:name => 'first',  :published => true);  first.save!
    second = p.articles.build(:name => 'second', :published => false); second.save!

    assert_equal [ first ], Article.recent(nil)
  end

  should 'not show documents from a private profile as recent' do
    p = fast_create(Person, :public_profile => false)
    Article.destroy_all

    first  = p.articles.build(:name => 'first',  :published => true);  first.save!
    second = p.articles.build(:name => 'second', :published => false); second.save!

    assert_equal [ ], Article.recent(nil)
  end

  should 'not show documents from a invisible profile as recent' do
    p = fast_create(Person, :visible => false)
    Article.destroy_all

    first  = p.articles.build(:name => 'first',  :published => true);  first.save!
    second = p.articles.build(:name => 'second', :published => false); second.save!

    assert_equal [ ], Article.recent(nil)
  end

  should 'order recent articles by published_at' do
    p = create_user('usr1').person
    Article.destroy_all

    now = Time.now

    first  = p.articles.build(:name => 'first',  :published => true, :created_at => now, :published_at => now);  first.save!
    second = p.articles.build(:name => 'second', :published => true, :updated_at => now, :published_at => now + 1.second); second.save!

    assert_equal [ second, first ], Article.recent(2)

    Article.record_timestamps = false
    first.update_attributes!(:published_at => second.published_at + 1.second)
    Article.record_timestamps = true

    assert_equal [ first, second ], Article.recent(2)
  end

  should 'not show UploadedFile as recent' do
    p = create_user('usr1').person
    Article.destroy_all

    first = UploadedFile.new(:profile => p, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'));  first.save!
    second = p.articles.build(:name => 'second'); second.save!

    assert_equal [ second ], Article.recent(nil)
  end

  should 'not show RssFeed as recent' do
    p = create_user('usr1').person
    Article.destroy_all
    first = RssFeed.create!(:profile => p, :name => 'my feed', :advertise => true)
    first.limit = 10; first.save!
    second = p.articles.build(:name => 'second'); second.save!

    assert_equal [ second ], Article.recent(nil)
  end

  should 'not show blog as recent' do
    p = create_user('usr1').person
    Article.destroy_all
    first = Blog.create!(:profile => p, :name => 'my blog', :advertise => true)
    second = p.articles.build(:name => 'second'); second.save!

    assert_equal [ second ], Article.recent(nil)
  end

  should 'accept extra conditions to find recent' do
    p = create_user('usr1').person
    Article.destroy_all
    a1 = p.articles.create!(:name => 'first')
    a2 = p.articles.create!(:name => 'second')

    assert_equal [ a1 ], Article.recent(nil, :name => 'first')
  end

  should 'require that subclasses define description' do
    assert_raise NotImplementedError do
      Article.description
    end
  end

  should 'require that subclasses define short description' do
    assert_raise NotImplementedError do
      Article.short_description
    end
  end

  should 'indicate wheter children articles are allowed or not' do
    assert_equal true, Article.new.allow_children?
  end

  should 'provide a url to itself' do
    article = profile.articles.build(:name => 'myarticle')
    article.save!

    assert_equal(profile.url.merge(:page => ['myarticle']), article.url)
  end

  should 'provide a url to itself having a parent topic' do
    parent = profile.articles.build(:name => 'parent');  parent.save!
    child = profile.articles.build(:name => 'child', :parent => parent); child.save!

    assert_equal(profile.url.merge(:page => [ 'parent', 'child']), child.url)
  end

  should 'associate with categories' do
    env = Environment.default
    c1 = env.categories.build(:name => "test category 1"); c1.save!
    c2 = env.categories.build(:name => "test category 2"); c2.save!

    article = profile.articles.build(:name => 'withcategories')
    article.save!

    article.add_category c1
    article.add_category c2

    assert_equivalent [c1,c2], article.categories(true)
  end

  should 'remove comments when removing article' do
    assert_no_difference Comment, :count do
      a = profile.articles.build(:name => 'test article')
      a.save!

      assert_difference Comment, :count, 1 do
        comment = a.comments.build
        comment.author = profile
        comment.title = 'test comment'
        comment.body = 'you suck!'
        comment.save!
      end

      a.destroy
    end
  end

  should 'list most commented articles' do
    Article.delete_all

    person = create_user('testuser').person
    articles = (1..4).map {|n| a = person.articles.build(:name => "art #{n}"); a.save!; a }

    2.times { articles[0].comments.build(:title => 'test', :body => 'asdsad', :author => person).save! }
    4.times { articles[1].comments.build(:title => 'test', :body => 'asdsad', :author => person).save! }

    # should respect the order (more commented comes first)
    assert_equal [articles[1], articles[0]], person.articles.most_commented(2)
  end

  should 'identify itself as a non-folder' do
    assert !Article.new.folder?, 'should identify itself as non-folder'
  end

  should 'identify itself as a non-blog' do
    assert !Article.new.blog?, 'should identify itself as non-blog'
  end

  should 'always display if public content' do
    person = create_user('testuser').person
    assert_equal true, person.home_page.display_to?(nil)
  end

  should 'display to owner' do
    # a person with private contents ...
    person = create_user('testuser').person
    person.update_attributes!(:public_content => false)

    # ... can see his own articles
    a = person.articles.create!(:name => 'test article')
    assert_equal true, a.display_to?(person)
  end

  should 'reindex when comments are changed' do
    a = Article.new
    a.expects(:ferret_update)
    a.comments_updated
  end

  should 'index comments title together with article' do
    owner = create_user('testuser').person
    art = owner.articles.build(:name => 'ytest'); art.save!
    c1 = art.comments.build(:title => 'a nice comment', :body => 'anything', :author => owner); c1.save!

    assert_includes Article.find_by_contents('nice'), art
  end

  should 'index comments body together with article' do
    owner = create_user('testuser').person
    art = owner.articles.build(:name => 'ytest'); art.save!
    c1 = art.comments.build(:title => 'test comment', :body => 'anything', :author => owner); c1.save!

    assert_includes Article.find_by_contents('anything'), art
  end

  should 'cache children count' do
    owner = create_user('testuser').person
    art = owner.articles.build(:name => 'ytest'); art.save!

    # two children articles
    art.children.create!(:profile => owner, :name => 'c1')
    art.children.create!(:profile => owner, :name => 'c2')

    art.reload

    assert_equal 2, art.children_count
    assert_equal 2, art.children.size

  end

  should 'categorize in the entire category hierarchy' do
    c1 = Category.create!(:environment => Environment.default, :name => 'c1')
    c2 = c1.children.create!(:environment => Environment.default, :name => 'c2')
    c3 = c2.children.create!(:environment => Environment.default, :name => 'c3')

    owner = create_user('testuser').person
    art = owner.articles.create!(:name => 'ytest')

    art.add_category(c3)

    assert_equal [c3], art.categories(true)
    assert_equal [art], c2.articles(true)

    assert_includes c3.articles(true), art
    assert_includes c2.articles(true), art
    assert_includes c1.articles(true), art
  end

  should 'redefine the entire category set at once' do
    c1 = Category.create!(:environment => Environment.default, :name => 'c1')
    c2 = c1.children.create!(:environment => Environment.default, :name => 'c2')
    c3 = c2.children.create!(:environment => Environment.default, :name => 'c3')
    c4 = c1.children.create!(:environment => Environment.default, :name => 'c4')
    owner = create_user('testuser').person
    art = owner.articles.create!(:name => 'ytest')

    art.add_category(c4)

    art.category_ids = [c2,c3].map(&:id)

    assert_equivalent [c2, c3], art.categories(true)
  end

  should 'be able to create an article already with categories' do
    c1 = Category.create!(:environment => Environment.default, :name => 'c1')
    c2 = Category.create!(:environment => Environment.default, :name => 'c2')

    p = create_user('testinguser').person
    a = p.articles.create!(:name => 'test', :category_ids => [c1.id, c2.id])

    assert_equivalent [c1, c2], a.categories(true)
  end

  should 'not add a category twice to article' do
    c1 = Category.create!(:environment => Environment.default, :name => 'c1')
    c2 = c1.children.create!(:environment => Environment.default, :name => 'c2')
    c3 = c1.children.create!(:environment => Environment.default, :name => 'c3')
    owner = create_user('testuser').person
    art = owner.articles.create!(:name => 'ytest')
    art.category_ids = [c2,c3,c3].map(&:id)
    assert_equal [c2, c3], art.categories(true)
  end

  should 'not accept Product category as category' do
    assert !Article.new.accept_category?(ProductCategory.new)
  end

  should 'accept published attribute' do
    assert_respond_to Article.new, :published
    assert_respond_to Article.new, :published=
  end

  should 'say that logged off user cannot see private article' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    article = Article.create!(:name => 'test article', :profile => profile, :published => false)

    assert !article.display_to?(nil)
  end 
  
  should 'say that not member of profile cannot see private article' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    article = Article.create!(:name => 'test article', :profile => profile, :published => false)
    person = create_user('test_user').person

    assert !article.display_to?(person)
  end
  
  should 'say that member user can not see private article' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    article = Article.create!(:name => 'test article', :profile => profile, :published => false)
    person = create_user('test_user').person
    profile.affiliate(person, Profile::Roles.member(profile.environment.id))

    assert !article.display_to?(person)
  end

  should 'say that profile admin can see private article' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    article = Article.create!(:name => 'test article', :profile => profile, :published => false)
    person = create_user('test_user').person
    profile.affiliate(person, Profile::Roles.admin(profile.environment.id))

    assert article.display_to?(person)
  end

  should 'say that profile moderator can see private article' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    article = Article.create!(:name => 'test article', :profile => profile, :published => false)
    person = create_user('test_user').person
    profile.affiliate(person, Profile::Roles.moderator(profile.environment.id))

    assert article.display_to?(person)
  end

  should 'not show article to non member if article public but profile private' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile', :public_profile => false)
    article = Article.create!(:name => 'test article', :profile => profile, :published => true)
    person1 = create_user('test_user1').person
    profile.affiliate(person1, Profile::Roles.member(profile.environment.id))
    person2 = create_user('test_user2').person

    assert !article.display_to?(nil)
    assert !article.display_to?(person2)
    assert article.display_to?(person1)
  end

  should 'make new article private if created inside a private folder' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    folder = Folder.create!(:name => 'my_intranet', :profile => profile, :published => false)
    article = Article.create!(:name => 'my private article', :profile => profile, :parent => folder)

    assert !article.published?
  end

  should 'save as private' do
    profile = Profile.create!(:name => 'test profile', :identifier => 'test_profile')
    folder = Folder.create!(:name => 'my_intranet', :profile => profile, :published => false)
    article = TextileArticle.new(:name => 'my private article')
    article.profile = profile
    article.parent = folder
    article.save!
    article.reload

    assert !article.published?
  end

  should 'not allow friends of private person see the article' do
    person = create_user('test_user').person
    article = Article.create!(:name => 'test article', :profile => person, :published => false)
    friend = create_user('test_friend').person
    person.add_friend(friend)
    person.save!
    friend.save!

    assert !article.display_to?(friend)
  end

  should 'display private articles to people who can view private content' do
    person = create_user('test_user').person
    article = Article.create!(:name => 'test article', :profile => person, :published => false)

    admin_user = create_user('admin_user').person
    admin_user.stubs(:has_permission?).with('view_private_content', article.profile).returns('true')

    assert article.display_to?(admin_user)
  end

  should 'make a copy of the article as child of it' do
    person = create_user('test_user').person
    a = person.articles.create!(:name => 'test article', :body => 'some text')
    b = a.copy(:parent => a, :profile => a.profile)
    
    assert_includes a.children, b
    assert_equal 'some text', b.body
  end

  should 'make a copy of the article to other profile' do
    p1 = create_user('test_user1').person
    p2 = create_user('test_user2').person
    a = p1.articles.create!(:name => 'test article', :body => 'some text')
    b = a.copy(:parent => a, :profile => p2)

    p2 = Person.find(p2.id)
    assert_includes p2.articles, b
    assert_equal 'some text', b.body
  end

  should 'mantain the type in a copy' do
    p = create_user('test_user').person
    a = Folder.create!(:name => 'test folder', :profile => p)
    b = a.copy(:parent => a, :profile => p)

    assert_kind_of Folder, b
  end

  should 'copy slug' do
    a = fast_create(Article, :slug => 'slug123')
    b = a.copy({})
    assert_equal a.slug, b.slug
  end

  should 'load article under an old path' do
    p = create_user('test_user').person
    a = p.articles.create(:name => 'old-name')
    old_path = a.explode_path
    a.name = 'new-name'
    a.save!

    page = Article.find_by_old_path(old_path)

    assert_equal a.path, page.path
  end

  should 'load new article name equal of another article old name' do
    p = create_user('test_user').person
    a1 = p.articles.create!(:name => 'old-name')
    old_path = a1.explode_path
    a1.name = 'new-name'
    a1.save!
    a2 = p.articles.create!(:name => 'old-name')

    page = Article.find_by_old_path(old_path)

    assert_equal a2.path, page.path
  end

  should 'article with most recent version with the name must be loaded if no aritcle with the name' do
    p = create_user('test_user').person
    a1 = p.articles.create!(:name => 'old-name')
    old_path = a1.explode_path
    a1.name = 'new-name'
    a1.save!
    a2 = p.articles.create!(:name => 'old-name')
    a2.name = 'other-new-name'
    a2.save!

    page = Article.find_by_old_path(old_path)

    assert_equal a2.path, page.path
  end

  should 'not return an article of a different user' do
    p1 = create_user('test_user').person
    a = p1.articles.create!(:name => 'old-name')
    old_path = a.explode_path
    a.name = 'new-name'
    a.save!

    p2 = create_user('another_user').person

    page = p2.articles.find_by_old_path(old_path)

    assert_nil page
  end

  should 'identify if belongs to blog' do
    p = create_user('user_blog_test').person
    blog = Blog.create!(:name => 'Blog test', :profile => p)
    post = TextileArticle.create!(:name => 'First post', :profile => p, :parent => blog)
    assert post.belongs_to_blog?
  end

  should 'not belongs to blog' do
    p = create_user('user_blog_test').person
    folder = Folder.create!(:name => 'Not Blog', :profile => p)
    a = TextileArticle.create!(:name => 'Not blog post', :profile => p, :parent => folder)
    assert !a.belongs_to_blog?
  end

  should 'has comments notifier true by default' do
    a = Article.new
    assert a.notify_comments?
  end

  should 'hold hits count' do
    a = Article.create!(:name => 'Test article', :profile => profile)
    a.hits = 10
    a.save!
    a.reload
    assert_equal 10, a.hits
  end

  should 'increment hit counter when hitted' do
    a = Article.create!(:name => 'Test article', :profile => profile, :hits => 10)
    a.hit
    assert_equal 11, a.hits
    a.reload
    assert_equal 11, a.hits
  end

  should 'have display_hits setting with default true' do
    a = Article.create!(:name => 'Test article', :profile => profile)
    assert_respond_to a, :display_hits
    assert_equal true, a.display_hits
  end

  should 'can display hits' do
    a = Article.create!(:name => 'Test article', :profile => profile)
    assert_respond_to a, :can_display_hits?
    assert_equal true, a.can_display_hits?
  end

  should 'return a view url when image' do
    image = UploadedFile.create!(:profile => profile, :uploaded_data => fixture_file_upload('/files/rails.png', 'image/png'))

    assert_equal image.url.merge(:view => true), image.view_url
  end

  should 'not return a view url when common article' do
    a = Article.create!(:name => 'Test article', :profile => profile)

    assert_equal a.url, a.view_url
  end

  should 'know its author' do
    assert_equal profile, Article.new(:last_changed_by => profile).author
  end

  should 'use owning profile as author when we dont know who did the last change' do
    assert_equal profile, Article.new(:last_changed_by => nil, :profile => profile).author
  end

  should 'have published_at' do
    assert_respond_to Article.new, :published_at
  end

  should 'published_at is same as created_at if not set' do
    a = Article.create!(:name => 'Published at', :profile => profile)
    assert_equal a.created_at, a.published_at
  end

  should 'use npage to compose cache key' do
    a = Article.create!(:name => 'Published at', :profile => profile)
    assert_match(/-npage-2/,a.cache_key(:npage => 2))
  end

  should 'use year and month to compose cache key' do
    a = Article.create!(:name => 'Published at', :profile => profile)
    assert_match(/-year-2009-month-04/, a.cache_key(:year => '2009', :month => '04'))
  end

  should 'not be highlighted by default' do
    a = Article.new
    assert !a.highlighted
  end

  should 'get tagged with tag' do
    a = Article.create!(:name => 'Published at', :profile => profile, :tag_list => 'bli')
    t = a.tags[0]
    as = Article.find_tagged_with(t)

    assert_includes as, a
  end

  should 'not get tagged with tag from other environment' do
    article_from_this_environment = create(Article, :profile => profile, :tag_list => 'bli')

    other_environment = fast_create(Environment)
    user_from_other_environment = create_user('other_user', :environment => other_environment).person
    article_from_other_enviroment = create(Article, :profile => user_from_other_environment, :tag_list => 'bli')

    tag = article_from_other_enviroment.tags.first
    tagged_articles_in_other_environment = other_environment.articles.find_tagged_with(tag)

    assert_includes tagged_articles_in_other_environment, article_from_other_enviroment
    assert_not_includes tagged_articles_in_other_environment, article_from_this_environment
  end

  should 'ignore category with zero as id' do
    a = profile.articles.create!(:name => 'a test article')
    c = Category.create!(:name => 'test category', :environment => profile.environment)
    a.category_ids = ['0', c.id, nil]
    assert a.save
    assert_equal [c], a.categories
  end

  should 'add owner on cache_key when has profile' do
    a = profile.articles.create!(:name => 'a test article')
    assert_match(/-owner/, a.cache_key({}, profile))
  end

  should 'not add owner on cache_key when has no profile' do
    a = profile.articles.create!(:name => 'a test article')
    assert_no_match(/-owner/, a.cache_key({}))
  end

  should 'add owner on cache_key when profile is community' do
    c = Community.create!(:name => 'new_comm')
    a = c.articles.create!(:name => 'a test article')
    assert_match(/-owner/, a.cache_key({}, c))
  end

  should 'have a creator method' do
    c = Community.create!(:name => 'new_comm')
    a = c.articles.create!(:name => 'a test article', :last_changed_by => profile)
    p = create_user('other_user').person
    a.update_attributes(:body => 'some content', :last_changed_by => p); a.save!
    assert_equal profile, a.creator
  end

  should 'allow creator to edit if is publisher' do
    c = Community.create!(:name => 'new_comm')
    p = create_user_with_permission('test_user', 'publish_content', c)
    a = c.articles.create!(:name => 'a test article', :last_changed_by => p)

    assert a.allow_post_content?(p)
  end

  should 'allow user with "Manage content" permissions to edit' do
    c = Community.create!(:name => 'new_comm')
    p = create_user_with_permission('test_user', 'post_content', c)
    a = c.articles.create!(:name => 'a test article')

    assert a.allow_post_content?(p)
  end

  should 'update slug from name' do
    article = Article.create!(:name => 'A test article', :profile => profile)
    assert_equal 'a-test-article', article.slug
    article.name = 'Changed name'
    assert_equal 'changed-name', article.slug
  end

  should 'find articles in a specific category' do
    env = Environment.default
    category_with_articles = env.categories.create!(:name => "Category with articles")
    category_without_articles = env.categories.create!(:name => "Category without articles")

    article_in_category = profile.articles.create!(:name => 'Article in category')

    article_in_category.add_category(category_with_articles)

    assert_includes profile.articles.in_category(category_with_articles), article_in_category
    assert_not_includes profile.articles.in_category(category_without_articles), article_in_category
  end

  should 'has external_link attr' do
    assert_nothing_raised NoMethodError do
      Article.new(:external_link => 'http://some.external.link')
    end
  end

  should 'validates format of external_link' do
    article = Article.new(:external_link => 'http://invalid-url')
    article.valid?
    assert_not_nil article.errors[:external_link]
  end

  should 'put http in external_link' do
    article = Article.new(:external_link => 'url.without.http')
    assert_equal 'http://url.without.http', article.external_link
  end

  should 'list only published articles' do
    profile = fast_create(Person)

    published  = profile.articles.create(:name => 'Published',  :published => true)
    unpublished = profile.articles.create(:name => 'Unpublished', :published => false)

    assert_equal [ published ], profile.articles.published
  end
end
