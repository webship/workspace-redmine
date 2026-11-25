# frozen_string_literal: true

# The Webship Workspace's Redmine builder and tool, run with Redmine's own Rails runner in the site's container, as
# Redmine's user:
#
#   bundle exec rails runner redmine-site.rb <verb>...
#
#   defaults  the first set-up of a new site, from the input (the base64 of a JSON object: admin_password, host,
#             protocol): Redmine's default data in English (trackers, statuses, roles, workflows, priorities,
#             activities), the REST API on, the host name and protocol of the links, and the administrator's password.
#   accounts  the accounts on the input (the base64 of a JSON list of login, mail, password, firstname, lastname,
#             admin, role, action): made, or given back their name, password and status; with a role, a member of the
#             sample project in it, without one a member of nothing there; with the action "lock", locked.
#   content   the sample content: the project "Webship site" with its issues, its version "Sprint 1" and a note, each
#             made where it is missing.
#   tidy      what a test run that was stopped half way left: its issues ("Webship test …"), with their time.
#   list      the default accounts, and what the sample project holds.
#   token     the API key of the active account whose login is on the input, made anew (its earlier one revoked), as
#             "TOKEN <value>" (for --connect, which writes it to the dashboard's settings; never shown).
#
# Nothing secret comes on its command line: passwords and logins travel on the input.

require 'base64'
require 'json'

PROJECT_IDENTIFIER = 'webship-site'
PROJECT_NAME = 'Webship site'
TEST_PREFIX = 'Webship test'
DEFAULT_LOGINS = %w[owner member reader stranger].freeze

def say(text)
  puts text
  $stdout.flush
end

# Kernel#warn says nothing when $VERBOSE is nil, as it is in a runner of the production environment.
def fail_with(text)
  $stderr.puts text
  $stderr.flush
  exit 1
end

def input_json
  raw = $stdin.read.to_s.strip
  fail_with('This verb reads the base64 of a JSON value on its input.') if raw.empty?
  JSON.parse(Base64.decode64(raw))
end

def defaults(options)
  if Redmine::DefaultData::Loader.no_data?
    Redmine::DefaultData::Loader.load('en')
    say 'defaults: Redmine\'s default data loaded (trackers, statuses, roles, workflows, priorities, activities)'
  end
  Setting.rest_api_enabled = '1'
  Setting.host_name = options['host'].to_s unless options['host'].to_s.empty?
  Setting.protocol = options['protocol'].to_s unless options['protocol'].to_s.empty?
  admin = User.find_by(login: 'admin')
  if admin && !options['admin_password'].to_s.empty?
    admin.password = options['admin_password']
    admin.password_confirmation = options['admin_password']
    admin.must_change_passwd = false
    admin.save!
  end
  say "defaults: the REST API on, links to #{Setting.protocol}://#{Setting.host_name}"
end

# The sample project, made the first time, with the modules the step pack and the tracker use, and every tracker.
def ensure_project
  project = Project.find_by(identifier: PROJECT_IDENTIFIER)
  unless project
    project = Project.new(name: PROJECT_NAME, identifier: PROJECT_IDENTIFIER, is_public: false,
                          description: 'The sample project of a Webship Workspace site: its issues, version and members are what the step pack and the tracker are tested on.')
    project.enabled_module_names = %w[issue_tracking time_tracking news documents files wiki repository boards calendar gantt]
    project.trackers = Tracker.all.to_a
    fail_with("The project #{PROJECT_NAME} could not be made: #{project.errors.full_messages.join('; ')}") unless project.save
    say "project: #{PROJECT_NAME} (#{PROJECT_IDENTIFIER}) made"
  end
  project
end

def role_named(name)
  Role.givable.find_by(name:) || fail_with("No role #{name} on the site.")
end

# The account's membership of the sample project: in the role, or none.
def membership(project, user, role_name)
  member = Member.find_by(project_id: project.id, user_id: user.id)
  if role_name.to_s.empty?
    if member
      member.destroy
      say "  #{user.login}: no longer a member of #{PROJECT_NAME}"
    end
    return
  end
  role = role_named(role_name)
  member ||= Member.new(project:, user:)
  member.role_ids = [role.id]
  member.save!
  say "  #{user.login}: #{role.name} of #{PROJECT_NAME}"
end

def accounts(rows)
  project = rows.any? { |r| !r['role'].to_s.empty? } ? ensure_project : Project.find_by(identifier: PROJECT_IDENTIFIER)
  rows.each do |r|
    login = r['login'].to_s
    fail_with('An account row has no login.') if login.empty?
    user = User.find_by(login:)
    if r['action'] == 'lock'
      if user.nil?
        say "  #{login}: no such account"
      elsif user.admin?
        say "  #{login}: an administrator, left as it is"
      else
        user.lock!
        say "  #{login}: locked"
      end
      next
    end
    user ||= User.new
    user.login = login
    user.mail = r['mail'].to_s
    user.firstname = r['firstname'].to_s.empty? ? login.capitalize : r['firstname']
    user.lastname = r['lastname'].to_s.empty? ? 'Test' : r['lastname']
    user.admin = true if r['admin']
    user.status = User::STATUS_ACTIVE
    user.language = 'en'
    user.must_change_passwd = false
    user.password = r['password']
    user.password_confirmation = r['password']
    fail_with("The account #{login} could not be saved: #{user.errors.full_messages.join('; ')}") unless user.save
    say "  #{login}: #{user.admin? ? 'administrator' : 'account'} ready (#{user.mail})"
    membership(project, user, r['role']) if project && r.key?('role') && !r['admin']
  end
end

def make_issue(project, author, tracker, subject, body, assignee: nil, version: nil, status: nil)
  existing = Issue.find_by(project_id: project.id, subject:)
  return [existing, false] if existing

  issue = Issue.new(project:, tracker:, author:, subject:, description: body,
                    priority: IssuePriority.default || IssuePriority.first, status: status || tracker.default_status)
  issue.assigned_to = assignee if assignee
  issue.fixed_version = version if version
  fail_with("The issue \"#{subject}\" could not be made: #{issue.errors.full_messages.join('; ')}") unless issue.save
  [issue, true]
end

def content
  project = ensure_project
  owner, member, stranger = %w[owner member stranger].map { |l| User.find_by(login: l) }
  fail_with('The default accounts are not on the site: add them first (--add-users).') unless owner && member && stranger

  version = Version.find_by(project_id: project.id, name: 'Sprint 1') ||
            Version.create!(project:, name: 'Sprint 1', status: 'open', sharing: 'none', effective_date: Date.current + 11)
  bug = Tracker.find_by(name: 'Bug') || Tracker.first
  feature = Tracker.find_by(name: 'Feature') || Tracker.first

  progress = IssueStatus.find_by(name: 'In Progress')
  greeting, made = make_issue(project, owner, bug, 'The greeting script says Helo instead of Hello', <<~MD, assignee: member, version:, status: progress)
    ### Problem/Motivation

    `bash greeting.sh World` prints `Helo, World!`.

    ### Proposed resolution

    Print `Hello, World!`, and keep the usage line as it is.
  MD
  if made
    # Read again first: saving the issue updated it in the database (its place in the tree), and its lock version too.
    greeting.reload.init_journal(owner, 'The script is in the project\'s repository: `greeting.sh`.')
    greeting.save!
  end
  make_issue(project, member, bug, 'The usage page spells greeting as greting', <<~MD)
    ### Problem/Motivation

    The usage line of `greeting.sh` says "greting".

    ### Proposed resolution

    Spell it "greeting".
  MD
  # Opened by an account with no membership: the tracker treats it as from outside the project.
  make_issue(project, stranger, feature, 'An issue opened by someone outside the project', <<~MD)
    Please also print the date after the greeting.
  MD
  say "content: #{PROJECT_NAME} holds #{Issue.where(project_id: project.id).count} issues, #{version.name} (#{version.status})"
end

def tidy
  left = Issue.where('subject LIKE ?', "#{TEST_PREFIX}%").to_a
  left.each(&:destroy)
  say "tidy: #{left.size} issue(s) of a stopped test run removed"
end

def list
  project = Project.find_by(identifier: PROJECT_IDENTIFIER)
  say 'Accounts:'
  User.where(login: DEFAULT_LOGINS).or(User.where(admin: true)).where(type: 'User').order(:id).each do |u|
    role = project && Member.find_by(project_id: project.id, user_id: u.id)&.roles&.map(&:name)&.join(', ')
    status = { User::STATUS_ACTIVE => 'active', User::STATUS_REGISTERED => 'registered', User::STATUS_LOCKED => 'locked' }[u.status] || u.status.to_s
    say format('  %-12s %-28s %-10s %s', u.login, u.mail, status, u.admin? ? 'administrator' : (role.to_s.empty? ? 'no membership' : role))
  end
  return say("No project #{PROJECT_NAME} (#{PROJECT_IDENTIFIER}) yet: --sample-content adds it.") unless project

  issues = Issue.where(project_id: project.id)
  say "#{PROJECT_NAME} (#{PROJECT_IDENTIFIER}): #{issues.count} issues (#{issues.open.count} open), " \
      "#{Version.where(project_id: project.id).count} version(s), #{TimeEntry.where(project_id: project.id).count} time entries"
end

def token(login)
  user = User.active.find_by(login:) || fail_with("No active account #{login} on the site.")
  Token.where(user_id: user.id, action: 'api').delete_all
  user.reload
  puts "TOKEN #{user.api_key}"
end

verbs = ARGV.dup
fail_with('A verb, please: defaults, accounts, content, tidy, list or token.') if verbs.empty?
verbs.each do |verb|
  case verb
  when 'defaults' then defaults(input_json)
  when 'accounts' then accounts(input_json)
  when 'content' then content
  when 'tidy' then tidy
  when 'list' then list
  when 'token' then token($stdin.gets.to_s.strip)
  else fail_with("Not a verb: #{verb} (defaults, accounts, content, tidy, list, token).")
  end
end
