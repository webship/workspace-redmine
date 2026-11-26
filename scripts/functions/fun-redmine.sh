#!/usr/bin/env bash

# Redmine for the Webship Workspace: build a site of Redmine (the open-source project management and issue tracking
# software) from the official image, run its own tools in its container, add its default accounts and their
# memberships, add its sample content, and wire its step pack into the testing setup.
#
# Placed by `plugins.sh --install redmine` in core/scripts/plugins/redmine/functions/, where bootstrap sources it after
# the core's own functions. Everything runs in containers, never on the host:
#   - DDEV (the default): Redmine's image is a service of a generic project, on the project's own PostgreSQL (the db
#     service), at https://<name>.ddev.site; the project's web container keeps the mail catcher.
#   - Docker Compose (--runtime docker): the official image is the web container's (rt_stack image), on the project's
#     PostgreSQL, its server started by the stack (rt_serve) through the image's own entrypoint, at http://127.0.0.1:<port>.
# Podman, Kubernetes, Lando and Docksal are not proven yet: asked for one, the builder says so and changes nothing.
#
# The container tool has no project type for Redmine, so a site of this plugin is recognised by a file on DDEV
# (.ddev/config.redmine.yaml, written by the builder) and by the plugin's claim on the other runtimes (rt_claim).
# Four names are the ones the core's tools look for:
#   set_redmine_users          the default accounts                          (cmd-tools-add-users.sh <project> redmine)
#   add_redmine_users          make them, and their memberships              (the same tool, and --add-users of the builder)
#   cancel_redmine_users       lock them                                     (cmd-tools-cancel-users.sh <project> redmine)
#   testing_configure_redmine  the step pack in the testing stack            (cmd-tools-testing.sh <project>)

# The step pack a site is tested with, and the release line it is required at.
readonly REDMINE_STEPS_PACKAGE='@webship-js/redmine-steps';
readonly REDMINE_STEPS_VERSION='^2.0.0';

# The release the builder runs when none is asked for (a tag of the official image).
readonly REDMINE_DEFAULT_VERSION='7.0.3';

# The sample project the default accounts are members of (its identifier and its name), and the folder of a site with
# the plugin's scripts and the site's own values (its container reads them at /opt/webship on DDEV).
readonly REDMINE_PROJECT='webship-site';
readonly REDMINE_PROJECT_NAME='Webship site';
readonly REDMINE_FILES='redmine';

# The default accounts, the ones a scenario logs in as: a Manager of the sample project (owner), a Developer (member),
# a Reporter (reader), and an account with no membership (stranger), whose issue the tracker treats as from outside
# the project. Accounts are configuration, made once on the site; a test suite never creates or deletes
# one. The workspace account the builder makes with --install is an administrator of its own and is not in this list.
function set_redmine_users() {
  users=(owner member reader stranger);
  local user ;
  for user in "${users[@]}" ; do
    printf -v "user_${user}_name" '%s' "${user}" ;
    printf -v "user_${user}_mail" '%s' "${user}@example.com" ;
    printf -v "user_${user}_password" '%s' 'dD.123123ddd' ;
    printf -v "user_${user}_fullname" '%s' "${user^} Test" ;
  done
  user_owner_role='Manager' ;
  user_member_role='Developer' ;
  user_reader_role='Reporter' ;
  user_stranger_role='' ;
}

# The runtime of the project in this folder, or of a new build (--runtime, else the workspace's setting, else DDEV).
# A core without the runtime layer has DDEV only.
function redmine_runtime() {
  if declare -f runtime_of > /dev/null ; then runtime_of "$@" ; else echo 'ddev' ; fi
}

# The address of the site in this folder (or of a new build named PROJECT_NAME, on DDEV).
function redmine_url() {
  if [ "$(redmine_runtime)" != 'ddev' ] && declare -f rt_url > /dev/null ; then rt_url ; return ; fi
  echo "https://${1:-${PROJECT_NAME}}.ddev.site" ;
}

# Is this folder a Redmine site of this plugin? On DDEV the builder leaves .ddev/config.redmine.yaml in it;
# on another runtime the project carries the plugin's claim.
function redmine_is_project() {
  local project_path="$1" ;
  [ -f "${project_path}/.ddev/config.redmine.yaml" ] && return 0 ;
  if declare -f rt_is_platform > /dev/null ; then rt_is_platform "${project_path}" redmine ; return $? ; fi
  return 1 ;
}

# Go to the project a tool was asked about, or say why not.
function redmine_enter_project() {
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}";
  if [ ! -d "${project_path}" ] ; then
    echo "No project ${PROJECT_NAME} in ${WORKSPACE_ROOT}/${doc_name}." ;
    return 1 ;
  fi
  if ! redmine_is_project "${project_path}" ; then
    echo "${doc_name}/${PROJECT_NAME} is not a Redmine site of this plugin." ;
    return 1 ;
  fi
  redmine_refresh_files "${project_path}" || return 1 ;
  cd "${project_path}" || return 1 ;
}

# The site's copy of the plugin's scripts (redmine/), brought up to the installed plugin's, so a plugin updated
# with --install reaches the sites built before it. The site's own values (redmine/env) are left as they are.
function redmine_refresh_files() {
  local project_path="$1" from="${WORKSPACE_SCRIPTS}/plugins/redmine" f ;
  [ -d "${project_path}/${REDMINE_FILES}" ] || return 0 ;
  for f in redmine-site.rb redmine-serve.sh ; do
    if [ -f "${from}/${f}" ] && ! cmp -s "${from}/${f}" "${project_path}/${REDMINE_FILES}/${f}" ; then
      cp "${from}/${f}" "${project_path}/${REDMINE_FILES}/${f}" || return 1 ;
    fi
  done
}

# A value of the site's own values (redmine/env), never printed by the tools: REDMINE_VERSION.
function redmine_setting() {
  sed -n "s/^$1=\\(.*\\)\$/\\1/p" "${2:-.}/${REDMINE_FILES}/env" 2>/dev/null | head -n 1 ;
}

# A value made for this site only: letters and digits.
function redmine_secret() {
  head -c 96 /dev/urandom | base64 -w0 | tr -dc 'A-Za-z0-9' | head -c "${1:-64}" ;
}

# Write the project's files: on DDEV Redmine's service (.ddev/docker-compose.redmine.yaml), the release in
# .ddev/.env and the claim (.ddev/config.redmine.yaml); on another runtime the claim, the official image as the
# web container's and its start (rt_claim, rt_stack, rt_web_build, rt_serve). Then the plugin's scripts and the site's
# own values (redmine/env, which only you can read): its secret key, the first administrator's password, the mail.
function redmine_write_config() {
  local project_path="$1" version="$2" runtime="$3" ;
  local from="${WORKSPACE_SCRIPTS}/plugins/redmine" f ;
  for f in docker-compose.redmine.yaml redmine-site.rb redmine-serve.sh ; do
    if [ ! -f "${from}/${f}" ] ; then
      echo "${f} is not in ${from}: install the plugin (plugins.sh --install redmine)." ;
      return 1 ;
    fi
  done
  mkdir -p "${project_path}/${REDMINE_FILES}" || return 1 ;
  for f in redmine-site.rb redmine-serve.sh ; do
    cp "${from}/${f}" "${project_path}/${REDMINE_FILES}/${f}" || return 1 ;
  done

  local env="${project_path}/${REDMINE_FILES}/env" ;
  ( umask 077 && cat > "${env}" <<ENVEOF
# The values of this Redmine site, made by the Redmine builder of the workspace: its secret key is of this site only.
# Read by the site's container; never printed. REDMINE_ADMIN_PASSWORD is the password of its first administrator.
REDMINE_VERSION=${version}
SECRET_KEY_BASE=$(redmine_secret 96)
REDMINE_ADMIN_PASSWORD=$(redmine_secret 24)
REDMINE_DB_POSTGRES=db
REDMINE_DB_USERNAME=db
REDMINE_DB_PASSWORD=db
REDMINE_DB_DATABASE=db
ENVEOF
  ) || return 1 ;

  if [ "${runtime}" = 'ddev' ] ; then
    cp "${from}/docker-compose.redmine.yaml" "${project_path}/.ddev/docker-compose.redmine.yaml" || return 1 ;
    printf 'REDMINE_VERSION=%s\n' "${version}" > "${project_path}/.ddev/.env" || return 1 ;
    cat > "${project_path}/.ddev/config.redmine.yaml" <<YAMLEOF
# Redmine in this project: its service (docker-compose.redmine.yaml), the release in .env, the site's own values in
# ../redmine/env. Written by the Redmine builder of the workspace; build again rather than editing.
web_environment:
  - REDMINE_VERSION=${version}
YAMLEOF
    return 0 ;
  fi

  # Another runtime: the official image is the web container's, and the stack starts it (redmine-serve.sh).
  ( cd "${project_path}" \
    && rt_claim redmine \
    && rt_stack image "redmine:${version}" \
    && rt_web_build redmine <<'DOCKEREOF'
# What Redmine writes while it runs (its files, its plugins' assets) belongs to the host user, www-data with the host's
# UID by now; the folders the image leaves open to everyone (config, log, tmp, public/assets) stay as they are.
RUN chown -R www-data:www-data /usr/src/redmine/files /usr/src/redmine/public/plugin_assets
DOCKEREOF
  ) || return 1 ;
  ( cd "${project_path}" && rt_serve 3000 "bash ${REDMINE_FILES}/redmine-serve.sh" ) || return 1 ;
}

# Run a command line in Redmine's container, as Redmine's own user, in its folder (/usr/src/redmine), with the site's
# values; what is piped in reaches it.
function redmine_exec() {
  local line="$1" ;
  if [ "$(redmine_runtime)" = 'ddev' ] ; then
    ddev exec -s redmine "gosu redmine bash -c $(printf '%q' "cd /usr/src/redmine && ${line}")" ;
  else
    ddev exec "set -a ; . /var/www/html/${REDMINE_FILES}/env ; set +a ; cd /usr/src/redmine && ${line}" ;
  fi
}

# The folder the plugin's scripts are read from in Redmine's container.
function redmine_scripts_dir() {
  if [ "$(redmine_runtime)" = 'ddev' ] ; then echo '/opt/webship' ; else echo "/var/www/html/${REDMINE_FILES}" ; fi
}

# The answer of Redmine's login page (200 when it serves and reaches its database), asked inside the project's network:
# on DDEV from the web container, elsewhere inside its own container.
function redmine_probe() {
  if [ "$(redmine_runtime)" = 'ddev' ] ; then
    ddev exec "curl -s -o /dev/null -m 10 -w '%{http_code}' http://redmine:3000/login" < /dev/null 2>/dev/null | tr -d '\r' | tail -1 ;
  else
    ddev exec "curl -s -o /dev/null -m 10 -w '%{http_code}' http://127.0.0.1:3000/login" < /dev/null 2>/dev/null | tr -d '\r' | tail -1 ;
  fi
}

# Wait until the site answers, in the project's folder: up to fifteen minutes, as the first start migrates the
# database.
function redmine_wait() {
  local attempt code="" ;
  for attempt in $(seq 1 300) ; do
    code="$(redmine_probe)" ;
    [ "${code}" == '200' ] && return 0 ;
    sleep 3 ;
  done
  echo "Redmine did not answer (its login page: ${code:-none}); the end of its log:" ;
  if [ "$(redmine_runtime)" = 'ddev' ] ; then ddev logs -s redmine --tail 40 < /dev/null 2>/dev/null ; else ddev logs < /dev/null 2>/dev/null | tail -n 40 ; fi
  return 1 ;
}

# The release the site runs, as Redmine says it.
function redmine_version() {
  ( cd "${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" 2>/dev/null && redmine_exec "sed -n 's/^ *\\(MAJOR\\|MINOR\\|TINY\\) *= *\\([0-9]*\\).*/\\2/p' lib/redmine/version.rb | paste -sd." < /dev/null 2>/dev/null ) | tr -d '\r' | tail -n 1 ;
}

# Run verbs of redmine-site.rb (defaults, accounts, content, tidy, list, token) with Redmine's own Rails runner in its
# container. A payload (accounts, passwords) travels on the input, never on a command line.
function redmine_site() {
  local verbs="$*" ;
  # The log to its file, not on the screen: the runner of the production environment logs every mail it queues.
  redmine_exec "RAILS_LOG_TO_STDOUT= bundle exec rails runner $(redmine_scripts_dir)/redmine-site.rb ${verbs}" ;
}

# Rows of accounts for redmine-site.rb, as the base64 of its JSON list: "login|mail|password|first|last|admin|
# role|action" lines in REDMINE_ROWS, which travel to Python in the environment, never on a command line.
function redmine_accounts_payload() {
  REDMINE_ROWS="$1" python3 -c '
import base64, json, os
rows = []
for line in os.environ["REDMINE_ROWS"].split("\x1e"):
    if not line:
        continue
    login, mail, password, first, last, admin, role, action = line.split("\x1f")
    rows.append({"login": login, "mail": mail, "password": password, "firstname": first, "lastname": last,
                 "admin": admin == "yes", "role": role, "action": action})
print(base64.b64encode(json.dumps(rows).encode()).decode())' ;
}

# Build a Redmine site from nothing: the project and Redmine; with --install the workspace account as an
# administrator; with --add-users the default accounts, members of the sample project; with --sample-content the
# project's issues, version and note the step pack is tested on.
function redmine_build() {
  trim_project_name ;
  local version="${REDMINE_VERSION:-${site_redmine_version:-${REDMINE_DEFAULT_VERSION}}}" ;
  local project_path="${WORKSPACE_ROOT}/${doc_name}/${PROJECT_NAME}" ;
  local runtime ; runtime="$(cd "${WORKSPACE_ROOT}/${doc_name}" && redmine_runtime)" ;

  case "${runtime}" in
    ddev|docker) ;;
    *) echo "Redmine builds on DDEV and on Docker Compose for now (--runtime ddev or docker), not on ${runtime}: that runtime is not proven for it yet. Nothing was changed." ; exit 1 ;;
  esac
  if [ "${runtime}" != 'ddev' ] && ! declare -f rt_stack > /dev/null ; then
    echo "--runtime ${runtime} needs a Webship Workspace with the container runtimes (webship/workspace#694, #841): update the workspace, or build on DDEV." ;
    exit 1 ;
  fi
  if ! [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
    echo "--redmine-version takes a release (7.0.3), not ${version}. Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${ADD_USERS}" == 'yes' ] && [ "${INSTALL}" != 'yes' ] ; then
    echo "--add-users needs --install: the default accounts go into the site --install sets up." ;
    exit 1 ;
  fi
  if [ "${SAMPLE_CONTENT}" == 'yes' ] && [ "${ADD_USERS}" != 'yes' ] ; then
    echo "--sample-content needs --add-users: the sample project's members are the default accounts." ;
    exit 1 ;
  fi
  if [ ${#PROJECT_NAME} -gt 40 ] || ! [[ "${PROJECT_NAME}" =~ ^[a-z0-9][a-z0-9-]*$ ]] ; then
    echo "The project name ${PROJECT_NAME} must be small letters, digits and dashes (its address and its containers take it). Nothing was changed." ;
    exit 1 ;
  fi
  if [ "${INSTALL}" == 'yes' ] && [ ${#account_pass} -lt 8 ] ; then
    echo "The workspace account's password (core/config/settings.yml) has fewer than eight characters, which Redmine asks of a password: --install makes it an account of the site. Nothing was changed." ;
    exit 1 ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name} || exit 1 ;

  # A project of the same name goes first, with its containers and its volumes (Redmine's database and files).
  drop_database ;
  rm -rf "${PROJECT_NAME:?}" ;
  mkdir -p "${PROJECT_NAME}" ;
  cd "${project_path}" || exit 1 ;

  # A generic project on PostgreSQL 17.
  if [ "${runtime}" = 'ddev' ] ; then
    ddev config --project-type=generic --project-name=${PROJECT_NAME} --database=postgres:17 \
      --nodejs-version=$(ddev_nodejs_version) < /dev/null || exit 1 ;
  else
    ddev config --project-type=generic --webserver-type=generic --project-name=${PROJECT_NAME} --database=postgres:17 --auto < /dev/null || exit 1 ;
  fi
  redmine_write_config "${project_path}" "${version}" "${runtime}" || exit 1 ;
  local base_url ; base_url="$(redmine_url)" ;

  echo "Starting the project and Redmine ${version}: its image is about 600 MB the first time, and the first start migrates the database." ;
  ddev_up start -y < /dev/null || exit 1 ;
  redmine_wait || exit 1 ;

  # Redmine's default data (trackers, statuses, roles, workflows), the REST API on, the address of its links, and the
  # first administrator's password, of this site only.
  local scheme="${base_url%%://*}" host="${base_url#*://}" ;
  REDMINE_ADMIN="$(redmine_setting REDMINE_ADMIN_PASSWORD "${project_path}")" REDMINE_HOST="${host}" REDMINE_SCHEME="${scheme}" python3 -c '
import base64, json, os
print(base64.b64encode(json.dumps({"admin_password": os.environ["REDMINE_ADMIN"], "host": os.environ["REDMINE_HOST"], "protocol": os.environ["REDMINE_SCHEME"]}).encode()).decode())' \
    | redmine_site defaults || { echo "Redmine's default data could not be loaded." ; exit 1 ; } ;

  if [ "${INSTALL}" == 'yes' ] ; then
    echo "Making the workspace account an administrator of the site." ;
    local rows ;
    rows="${account_name}"$'\x1f'"${account_mail:-${account_name}@example.com}"$'\x1f'"${account_pass}"$'\x1f'"${account_name^}"$'\x1f''Workspace'$'\x1f''yes'$'\x1f'$'\x1f'$'\x1e' ;
    redmine_accounts_payload "${rows}" | redmine_site accounts || { echo "The workspace account could not be made." ; exit 1 ; } ;
    if [ "${ADD_USERS}" == 'yes' ] ; then
      set_redmine_users ;
      add_redmine_users || exit 1 ;
      if [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
        echo "Adding the sample content: the project ${REDMINE_PROJECT_NAME}'s issues, its version Sprint 1 and a note." ;
        ( cd "${project_path}" && redmine_site content < /dev/null ) || exit 1 ;
      fi
      users=() ;
    fi
    echo "${doc_name} ${PROJECT_NAME} has been installed: Redmine $(redmine_version).";
    echo "The site: ${base_url}" ;
    echo "The workspace account logs in as ${account_name}; the first administrator (admin) has a password of this site only, in ${doc_name}/${PROJECT_NAME}/${REDMINE_FILES}/env (REDMINE_ADMIN_PASSWORD).";
  else
    echo "${doc_name} ${PROJECT_NAME} is ready: Redmine $(redmine_version) at ${base_url}.";
    echo "Its first administrator (admin) has a password of this site only, in ${doc_name}/${PROJECT_NAME}/${REDMINE_FILES}/env (REDMINE_ADMIN_PASSWORD). Build it again with --install (and --add-users) for the workspace account and the default accounts.";
  fi

  if [ "${LAUNCH}" == 'yes' ] ; then
    ddev launch ;
  fi

  cd ${WORKSPACE_ROOT}/${doc_name};
}

# Make the default accounts, or give them back their names, passwords and status, with the first login done (no
# welcome dialog), and each a member of the sample project in its role (the stranger in none). The list is loaded by
# the caller (set_redmine_users): the core's add_users, the builder, the tool.
function add_redmine_users() {
  redmine_enter_project || return 1 ;
  local user user_name user_mail user_password user_fullname user_role rows="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    user_password="user_${user}_password"; user_fullname="user_${user}_fullname"; user_role="user_${user}_role";

    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo "  User password: ${!user_password}";
    echo "      User role: ${!user_role:-no membership} of ${REDMINE_PROJECT_NAME}";
    echo " ================================================================= ";
    rows="${rows}${!user_name}"$'\x1f'"${!user_mail}"$'\x1f'"${!user_password}"$'\x1f'"${!user_fullname% *}"$'\x1f'"${!user_fullname##* }"$'\x1f''no'$'\x1f'"${!user_role}"$'\x1f'$'\x1e' ;
  done
  redmine_accounts_payload "${rows}" | redmine_site accounts ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Lock the default accounts (they cannot log in any more; their work stays), never the workspace account.
function cancel_redmine_users() {
  redmine_enter_project || return 1 ;
  local user user_name user_mail rows="" ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_mail="user_${user}_mail";
    echo " ---------------------------------------------------------------- ";
    echo "      User name: ${!user_name}";
    echo "      User mail: ${!user_mail}";
    echo " ================================================================= ";
    rows="${rows}${!user_name}"$'\x1f'"${!user_mail}"$'\x1f'$'\x1f'$'\x1f'$'\x1f''no'$'\x1f'$'\x1f''lock'$'\x1e' ;
  done
  redmine_accounts_payload "${rows}" | redmine_site accounts ;
  local status=$? ;
  cd ${WORKSPACE_ROOT}/${doc_name};
  return ${status} ;
}

# Point the dashboard's Redmine (core/config/plugin.redmine.settings.yml) at this site, as an account of it:
# a new API key of that account goes into the settings file, which only you can read, never on a screen or in a
# log; with it the site's address, and the sample project as the default one when none was set.
function redmine_connect() {
  local login="$1" settings="${WORKSPACE_CONFIG}/plugin.redmine.settings.yml" out token url ;
  if ! [[ "${login}" =~ ^[A-Za-z0-9._@-]+$ ]] ; then echo "--connect takes the login of an account of the site." ; return 1 ; fi
  if [ ! -f "${settings}" ] ; then echo "No ${settings}: install the plugin first (plugins.sh --install redmine)." ; return 1 ; fi
  out="$(printf '%s\n' "${login}" | redmine_site token 2>/dev/null)" ;
  token="$(printf '%s\n' "${out}" | tr -d '\r' | sed -n 's/^TOKEN //p' | tail -n 1)" ;
  out='' ;
  if ! [[ "${token}" =~ ^[A-Za-z0-9_-]{20,}$ ]] ; then echo "No API key could be made for ${login} (is it an active account of the site?)." ; return 1 ; fi
  url="$(redmine_url)" ;
  REDMINE_NEW_TOKEN="${token}" python3 - "${settings}" "${url}" "${REDMINE_PROJECT}" <<'PYEOF' || return 1
import os, re, sys
path, url, project = sys.argv[1:4]
token = os.environ['REDMINE_NEW_TOKEN']
text = open(path).read()
def put(text, key, value):
    line = '%s: %s' % (key, value)
    if re.search(r'^%s:.*$' % key, text, re.M):
        return re.sub(r'^%s:.*$' % key, lambda m: line, text, count=1, flags=re.M)
    return text.rstrip('\n') + '\n' + line + '\n'
text = put(text, 'url', url)
text = put(text, 'token', token)
if not re.search(r'^default_scope:[ \t]*[^ \t\n"]', text, re.M) and not re.search(r'^default_scope:[ \t]*"[^"]', text, re.M):
    text = put(text, 'default_scope', project)
fd = os.open(path + '.new', os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as f:
    f.write(text)
os.replace(path + '.new', path)
PYEOF
  token='' ;
  echo "The dashboard reads the issues of ${url} as ${login} now: a new API key of that account is in ${settings} (not shown here), and ${REDMINE_PROJECT} is the default project when none was set." ;
}

# What cmd-tools-redmine-cli.sh does: the first of --run, --add-users, --cancel-users, --sample-content, --tidy,
# --connect that was asked for; with none of them, what the site is and its accounts.
function redmine_cli_tool() {
  trim_project_name ;
  redmine_enter_project || exit 1 ;

  if [ "$(redmine_runtime)" = 'ddev' ] ; then
    ddev describe -j 2>/dev/null | grep -q '"status":"running"' || ddev start -y < /dev/null || exit 1 ;
  else
    ddev start < /dev/null > /dev/null 2>&1 || ddev start -y < /dev/null || exit 1 ;
  fi
  redmine_wait > /dev/null || { echo "Redmine of ${PROJECT_NAME} does not answer; start it again (ddev restart in ${doc_name}/${PROJECT_NAME})." ; exit 1 ; } ;

  if [ ! "${RUN}" == '_none_' ] ; then
    # Redmine's own tasks (bundle exec rake <task>), in its container, as its user.
    redmine_exec "bundle exec rake ${RUN}" < /dev/null ;
    exit $? ;
  fi

  set_redmine_users ;
  if [ "${ADD_USERS}" == 'yes' ] ; then
    add_redmine_users ;
  elif [ "${CANCEL_USERS}" == 'yes' ] ; then
    cancel_redmine_users ;
  elif [ "${SAMPLE_CONTENT}" == 'yes' ] ; then
    redmine_site content list < /dev/null ;
  elif [ "${TIDY}" == 'yes' ] ; then
    # What a test run that was stopped half way left: its issues ("Webship test …"), with their time.
    redmine_site tidy list < /dev/null ;
  elif [ "${CONNECT}" != '_none_' ] ; then
    redmine_connect "${CONNECT}" ;
  else
    echo "${doc_name}/${PROJECT_NAME}: Redmine $(redmine_version)" ;
    echo "  the site:  $(redmine_url)" ;
    echo "" ;
    redmine_site list < /dev/null ;
  fi
  cd ${WORKSPACE_ROOT}/${doc_name};
}

# The step pack in the testing stack of a Redmine site. The core's testing_configure calls this in the project
# folder once webship-js is scaffolded and before the dependencies are installed; for a project that is not one of
# this plugin's it changes nothing.
#
# It adds the pack to package.json, lists its step definitions in cucumber.js after webship-js's own, gives cucumber.js
# the tags that keep the pack's assertions that must fail out of a normal run, the account that prepares and removes
# test content (manager), the project the steps work in when they name none, and the users registry of the default
# accounts (a handle a scenario reads, mapped to an account; never the workspace account), and writes a first feature
# when the project has none of its own. Every part is skipped when it is already there, so a second run adds what the
# first missed and never resets a suite.
function testing_configure_redmine() {
  local project_path="$1";
  redmine_is_project "${project_path}" || return 0 ;
  if [ ! -f "${project_path}/cucumber.js" ] || [ ! -f "${project_path}/package.json" ] ; then
    echo "  Redmine: cucumber.js is not here yet — run the testing setup again once webship-js is scaffolded." ;
    return 1 ;
  fi

  echo "Adding the Redmine step pack (${REDMINE_STEPS_PACKAGE} ${REDMINE_STEPS_VERSION}).";
  set_redmine_users ;
  local registry="" user user_name user_password user_fullname ;
  for user in "${users[@]}" ; do
    user_name="user_${user}_name"; user_password="user_${user}_password"; user_fullname="user_${user}_fullname";
    registry="${registry}${user}|${!user_name}|${!user_password}|${!user_fullname}"$'\n' ;
  done

  local address ;
  address="$(cd "${project_path}" && redmine_url "$(sed -n 's/^name:[[:space:]]*"\{0,1\}\([A-Za-z0-9._-]*\)"\{0,1\}[[:space:]]*$/\1/p' .ddev/config.yaml 2>/dev/null | head -n 1)")" ;

  python3 - "${project_path}" "${REDMINE_STEPS_PACKAGE}" "${REDMINE_STEPS_VERSION}" 'REDMINE' "${registry}" "${address}" "${REDMINE_PROJECT}" <<'PYEOF' || return 1
import json, re, sys

project, pack, version, prefix, registry, address, sample = sys.argv[1:8]

# package.json: the pack as a dev dependency, at the release line this plugin was proven on.
pkg_file = project + '/package.json'
pkg = json.load(open(pkg_file))
if pack not in pkg.get('dependencies', {}) and pack not in pkg.get('devDependencies', {}):
    pkg.setdefault('devDependencies', {})[pack] = version
    open(pkg_file, 'w').write(json.dumps(pkg, indent=4) + '\n')
    print('  package.json: %s %s' % (pack, version))

cucumber_file = project + '/cucumber.js'
src = open(cucumber_file).read()
before = src

if ('node_modules/%s/' % pack) not in src:
    line = "'node_modules/%s/tests/step-definitions/**/*.js'," % pack
    core = re.search(r"^([ \t]*)'node_modules/webship-js/tests/step-definitions/[^']*',.*$", src, re.M)
    opening = re.search(r"^([ \t]*)require:[ \t]*\[[ \t]*$", src, re.M)
    if core:
        src = src[:core.end()] + '\n' + core.group(1) + line + src[core.end():]
    elif opening:
        src = src[:opening.end()] + '\n' + opening.group(1) + '  ' + line + src[opening.end():]
    else:
        sys.exit("  cucumber.js has no require list this can add to. Add this line to it:\n    " + line)
    print('  cucumber.js: the step definitions of %s' % pack)

if not re.search(r"^[ \t]*tags:", src, re.M):
    default = re.search(r"^([ \t]*)default:[ \t]*\{[ \t]*$", src, re.M)
    if default:
        pad = default.group(1) + '  '
        block = [
            pad + "// The pack's assertions that must fail are no part of a normal run.",
            pad + "tags: process.env.CUCUMBER_TAGS || 'not @wip and not @must-fail',",
        ]
        src = src[:default.end()] + '\n' + '\n'.join(block) + src[default.end():]
        print('  cucumber.js: the tags that keep the assertions that must fail out of a normal run')

world = re.search(r"^([ \t]*)worldParameters:[ \t]*\{[ \t]*$", src, re.M)
if not world:
    sys.exit("  cucumber.js has no worldParameters block to add the users registry to.")
pad = world.group(1) + '  '
additions = []
if not re.search(r"^[ \t]*manager:", src, re.M):
    additions += [
        pad + "// The account that prepares and removes test content through the site's API: a Manager of the project.",
        pad + "manager: process.env.MANAGER || 'owner',",
    ]
if not re.search(r"^[ \t]*project:", src, re.M):
    additions += [
        pad + "// The project the steps work in when they name none (its identifier).",
        pad + "project: process.env.PROJECT || '%s'," % sample,
    ]
if not re.search(r"^[ \t]*users:[ \t]*\{", src, re.M):
    rows = [r.split('|') for r in registry.splitlines() if r.strip()]
    additions += [
        pad + "// The users registry: a handle a scenario reads, mapped to an account of the site (the default accounts:",
        pad + "// cmd-tools-redmine-cli.sh --add-users). Override one with %s_<HANDLE>_USER and %s_<HANDLE>_PASSWORD." % (prefix, prefix),
        pad + "users: {",
    ]
    for handle, login, password, fullname in rows:
        env = '%s_%s' % (prefix, handle.upper())
        additions.append(pad + "  %s: { username: process.env.%s_USER || '%s', password: process.env.%s_PASSWORD || '%s', name: '%s' }," % (handle, env, login, env, password, fullname))
    additions.append(pad + "},")
    print('  cucumber.js: the users registry (%s)' % ', '.join(r[0] for r in rows))
if additions:
    src = src[:world.end()] + '\n' + '\n'.join(additions) + src[world.end():]
    print('  cucumber.js: the managing account and the project of the steps')

# The address the suite opens when LAUNCH_URL is not set: the placeholder of the scaffold becomes the site's.
placeholder = "process.env.LAUNCH_URL || 'http://localhost:8080'"
if placeholder in src:
    src = src.replace(placeholder, "process.env.LAUNCH_URL || '%s'" % address)
    print('  cucumber.js: the address of the site (%s)' % address)

if src != before:
    open(cucumber_file, 'w').write(src)
PYEOF

  # A first feature, when the project has none for the site yet.
  local feature="${WORKSPACE_SCRIPTS}/plugins/redmine/site.feature" ;
  if [ -f "${feature}" ] && [ ! -f "${project_path}/tests/features/site.feature" ] ; then
    mkdir -p "${project_path}/tests/features" && cp "${feature}" "${project_path}/tests/features/site.feature" \
      && echo "  tests/features/site.feature: a first feature for the issues" ;
  fi

  # The scenarios log in as the default accounts and read the sample project: make sure the site has them, once it
  # answers again (installing the testing stack may restart the project, and Redmine with it). Each part runs in the
  # project and says when it did not work: add_redmine_users ends in the sites folder, so the sample content is asked for
  # in the project again (webship/workspace-redmine#7).
  if ! ( cd "${project_path}" && redmine_wait > /dev/null 2>&1 ) ; then
    echo "  Redmine does not answer: is the site running (ddev start in ${project_path})? The default accounts and the sample content were not checked." ;
  elif ! ( cd "${project_path}" && add_redmine_users > /dev/null 2>&1 ) ; then
    echo "  The default accounts could not be written (bash cmd-tools-redmine-cli.sh <site> --add-users says why)." ;
  elif ! ( cd "${project_path}" && redmine_site content < /dev/null > /dev/null 2>&1 ) ; then
    echo "  The sample content could not be written (bash cmd-tools-redmine-cli.sh <site> --sample-content says why)." ;
  else
    echo "  the default accounts and the sample content are on the site (${users[*]})" ;
  fi
}
