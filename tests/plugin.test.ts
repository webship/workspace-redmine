import test from 'node:test';
import assert from 'node:assert';
import fs from 'fs';
import path from 'path';
import { spawnSync } from 'child_process';

import { assistantContext, PLATFORM, COMMANDS, AGENTS, SKILLS, AI_COMMANDS, PROMPTS } from '../src/index';

// Compiled, these tests run from dist/tests, so the package root is one folder further up.
const PKG = fs.existsSync(path.join(__dirname, '..', 'package.json')) ? path.join(__dirname, '..') : path.join(__dirname, '..', '..');
const read = (f: string) => fs.readFileSync(path.join(PKG, f), 'utf8');
const pkg = JSON.parse(read('package.json'));
const manifest = pkg.workspacePlugin;
const FUN = read('scripts/functions/fun-redmine.sh');

test('the manifest names the platform, and every file it names ships', () => {
  assert.strictEqual(manifest.name, PLATFORM);
  const named = [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, ...manifest.scripts.machine,
    ...manifest.ai.agents, ...manifest.ai.skills, ...manifest.ai.commands, ...manifest.ai.prompts, ...manifest.features, manifest.settingsTemplate, manifest.labels];
  for (const f of named) assert.ok(fs.existsSync(path.join(PKG, f)), `${f} is in the package`);
  for (const f of named) assert.ok(pkg.files.includes(f.split('/')[0]), `${f} is published with the package`);
  assert.deepStrictEqual(manifest.commands.files.map((f: string) => path.basename(f)), COMMANDS);
  assert.deepStrictEqual(manifest.ai.agents.map((f: string) => path.basename(f, '.md')), AGENTS);
  assert.deepStrictEqual(manifest.ai.skills.map((f: string) => path.basename(f)), SKILLS);
  assert.deepStrictEqual(manifest.ai.commands.map((f: string) => path.basename(f, '.md')), AI_COMMANDS);
  assert.deepStrictEqual(manifest.ai.prompts.map((f: string) => path.basename(f, '.md')), PROMPTS);
  assert.deepStrictEqual(manifest.commands.types, ['sites'], 'the commands go to sites folders only');
  assert.deepStrictEqual(manifest.typeActions, { redmine: ['sites', 'code'] }, 'the REDMINE menu on the rows of sites and code folders');
  // The machine files land side by side in core/scripts/plugins/redmine/: no two may share a name.
  const names = manifest.scripts.machine.map((f: string) => path.basename(f));
  assert.strictEqual(new Set(names).size, names.length, 'the machine files have names of their own');
  assert.strictEqual(manifest.featuresSite, 'cmd-redmine-project.sh ci-redmine --install --add-users --sample-content --runtime docker', 'CI builds a site on Docker Compose for the features');
  assert.deepStrictEqual(pkg.dependencies, { '@webship.co/workspace-tracker': '^1.0.2' });
});

test('every command finds the workspace by itself, names its folder, and sources its args from where the installer puts them', () => {
  for (const f of manifest.commands.files) {
    const src = read(f);
    assert.match(src, /^#!\/usr\/bin\/env bash/, `${f} is a bash script`);
    assert.match(src, /WORKSPACE_SCRIPTS="\$\{WORKSPACE_SCRIPTS:-\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)\/\.\.\/core\/scripts" && pwd\)\}"/, `${f} locates the tooling from its own path`);
    assert.match(src, /workspace\.__WORKSPACE__\.settings\.yml/, `${f} loads the settings of the folder it is installed into`);
    assert.match(src, /source \$\{WORKSPACE_SCRIPTS\}\/plugins\/redmine\/args\/arg-[a-z-]+\.sh \|\| exit 1 ;/, `${f} reads its arguments from the plugin's args`);
    const last = src.trim().split('\n').pop() as string;
    assert.match(FUN, new RegExp(`^function ${last.replace(/ ;$/, '')}\\(\\)`, 'm'), `${f} ends by calling a function the plugin defines`);
  }
  assert.match(read('commands/cmd-redmine-project.sh'), /^# workspace-name: Redmine \(project management and issue tracking\)$/m, 'the builder carries the name the Build list shows');
  assert.doesNotMatch(read('commands/cmd-tools-redmine-cli.sh'), /^# workspace-name:/m, 'a tool is not a builder');
});

test('every shell script parses, and the site\'s script is Ruby the site\'s own runner reads', () => {
  for (const f of [...manifest.commands.files, ...manifest.scripts.functions, ...manifest.scripts.args, 'scripts/redmine-serve.sh']) {
    const r = spawnSync('bash', ['-n', path.join(PKG, f)], { encoding: 'utf8' });
    assert.strictEqual(r.status, 0, `${f}: ${r.stderr}`);
  }
  const rb = read('scripts/redmine-site.rb');
  for (const verb of ['defaults', 'accounts', 'content', 'tidy', 'list', 'token']) assert.match(rb, new RegExp(`when '${verb}'`), `the runner script answers ${verb}`);
  assert.match(rb, /Setting\.rest_api_enabled = '1'/, 'the REST API on, which the tracker and the step pack use');
  assert.match(rb, /Redmine::DefaultData::Loader\.load\('en'\)/, 'the default data in English');
  assert.doesNotMatch(rb, /^\s*warn /m, 'Kernel#warn says nothing in a production runner: failures go to $stderr');
  assert.doesNotMatch(rb, /update_column/, 'the sample content is made as it should be, not changed after');
});

test('the runtimes: DDEV, Docker Compose, Podman and Kubernetes; another is refused before anything is changed', () => {
  assert.match(read('scripts/args/arg-redmine.sh'), /choices=\['ddev', 'docker', 'podman', 'kubernetes'\]/);
  const build = FUN.slice(FUN.indexOf('function redmine_build()'));
  const guard = build.indexOf('case "${runtime}" in');
  assert.ok(guard > 0 && guard < build.indexOf('drop_database') && guard < build.indexOf('ddev config'), 'the runtime is asked first');
  assert.match(build, /    ddev\|docker\|podman\|kubernetes\) ;;\n/, 'the four runtimes');
  assert.ok(build.includes('Redmine builds on DDEV, Docker Compose, Podman and Kubernetes for now (--runtime ddev, docker, podman or kubernetes), not on ${runtime}: that runtime is not proven for it yet. Nothing was changed.'));
  for (const f of ['README.md', 'src/index.ts', 'commands/cmd-redmine-project.sh', 'scripts/functions/fun-redmine.sh', 'scripts/args/arg-redmine.sh', ...manifest.ai.agents, ...manifest.ai.prompts]) {
    assert.doesNotMatch(read(f), /Podman, Kubernetes, Lando and Docksal are not proven|Other runtimes are not proven|not proven on the other runtimes/, `${f}: no runtime said unproven that is proven`);
  }
  const features = read('features/redmine-runtimes.feature');
  for (const [rt, menu] of [['docker', 'DOCKER'], ['podman', 'PODMAN'], ['kubernetes', 'K8S']]) {
    assert.match(features, new RegExp(`@needs-runtime-${rt} @needs-platform-redmine\\n  Scenario: A site built on [A-Za-z ]+ runs at [a-z ]+, with the ${menu} menu`), `the dashboard's row of a ${rt} site`);
    assert.match(features, new RegExp(`When I open "/login" on the "${rt}" site`), `the login screen of a ${rt} site`);
  }
  assert.ok(build.indexOf('redmine_site defaults') > build.indexOf('redmine_wait'), 'the default data once the site answers');
  const write = FUN.slice(FUN.indexOf('function redmine_write_config()'), FUN.indexOf('function redmine_exec()'));
  assert.match(write, /rt_claim redmine/, 'the plugin claims the project on another runtime');
  assert.match(write, /rt_stack image "docker\.io\/library\/redmine:\$\{version\}"/, 'the official image, pinned, is the web container\'s, by its full name, which Podman needs');
  assert.ok(write.indexOf("printf 'REDMINE_ATTACHMENTS_STORAGE_PATH=/var/www/html/%s/files\\n' \"${REDMINE_FILES}\" >> \"${env}\"") > write.indexOf("if [ \"${runtime}\" = 'ddev' ]"), 'off DDEV the attachments in the project folder: not in the image\'s volume, which a new container or pod does not have and a Backup does not take');
  const serve = read('scripts/redmine-serve.sh');
  assert.ok(serve.indexOf('mkdir -p "${REDMINE_ATTACHMENTS_STORAGE_PATH}" || exit 1 ;') > 0 && serve.indexOf("printf 'production:\\n  attachments_storage_path: %s\\n' \"${REDMINE_ATTACHMENTS_STORAGE_PATH}\" > config/configuration.yml || exit 1 ;") > serve.indexOf('mkdir -p') && serve.indexOf('configuration.yml') < serve.indexOf('exec /docker-entrypoint.sh'), 'Redmine pointed at that folder before it starts, when the site\'s env says so');
  const readme = read('README.md');
  const upgrade = readme.slice(readme.indexOf('### Upgrading a Docker Compose site from 1.0.2'), readme.indexOf('## The tool'));
  const steps = ['bash cmd-tools-redmine-cli.sh mysite', 'mkdir -p redmine/files', 'docker compose cp web:/usr/src/redmine/files/. redmine/files/', "echo 'REDMINE_ATTACHMENTS_STORAGE_PATH=/var/www/html/redmine/files' >> redmine/env", 'docker compose restart web'];
  for (let i = 1; i < steps.length; i++) assert.ok(upgrade.indexOf(steps[i - 1]) >= 0 && upgrade.indexOf(steps[i - 1]) < upgrade.indexOf(steps[i]), `the upgrade of a 1.0.2 Docker Compose site, in order: ${steps[i]}`);
  assert.match(readme, /on DDEV in the project's volume `ddev-mysite-redmine-files`, which the row's Backup does not\n  hold; on Docker Compose, Podman and Kubernetes in the project folder \(`redmine\/files`\)/, 'where the attachments live on each runtime');
  assert.match(write, /chown -R www-data:www-data \/usr\/src\/redmine\/files \/usr\/src\/redmine\/public\/plugin_assets/, 'what it writes belongs to the host user, whatever its UID');
  assert.match(write, /rt_serve 3000 "bash \$\{REDMINE_FILES\}\/redmine-serve\.sh"/);
  assert.match(write, /umask 077/, 'the site\'s own values are readable by their owner only');
  assert.match(read('scripts/redmine-serve.sh'), /exec \/docker-entrypoint\.sh rails server -b 0\.0\.0\.0 -p 3000/, 'the image\'s own start: the database settings, the migrations, the server');
});

test('Redmine\'s service on DDEV: the official image takes the project\'s address, on the project\'s database; the web container keeps the mail catcher', () => {
  const compose = read('scripts/docker-compose.redmine.yaml');
  assert.match(compose, /image: "redmine:\$\{REDMINE_VERSION:-7\.0\.3\}"/);
  assert.match(compose, /VIRTUAL_HOST: \$\{DDEV_HOSTNAME\}/, 'Redmine takes the project\'s address');
  assert.match(compose, /HTTP_EXPOSE: "80:3000"/);
  assert.match(compose, /HTTPS_EXPOSE=8457:80,8026:8025/, 'the web container moves, its mail catcher stays at :8026');
  assert.match(compose, /REDMINE_DB_POSTGRES: db/, 'the project\'s own PostgreSQL');
  assert.match(compose, /env_file:\n\s+- \$\{DDEV_APPROOT\}\/redmine\/env/, 'the site\'s own values from its file');
  assert.match(compose, /name: ddev-\$\{DDEV_SITENAME\}-redmine-files/, 'the files volume is the project\'s, removed with it');
  assert.doesNotMatch(compose, /SECRET_KEY_BASE:|ADMIN_PASSWORD:/, 'no secret in the compose file');
});

test('the functions carry the names the core\'s tools look for, and run Redmine\'s tools in its container as its user', () => {
  for (const fn of ['set_redmine_users', 'add_redmine_users', 'cancel_redmine_users', 'testing_configure_redmine', 'redmine_build', 'redmine_cli_tool', 'redmine_connect']) {
    assert.match(FUN, new RegExp(`^function ${fn}\\(\\) \\{`, 'm'), `${fn} is defined`);
  }
  assert.match(FUN, /ddev exec -s redmine "gosu redmine bash -c/, 'on DDEV in Redmine\'s container, as its own user');
  assert.match(FUN, /RAILS_LOG_TO_STDOUT= bundle exec rails runner \$\(redmine_scripts_dir\)\/redmine-site\.rb/, 'the site\'s own Rails runner, its log to its file');
  assert.match(FUN, /redmine_exec "bundle exec rake \$\{RUN\}"/, 'the tool runs Redmine\'s own tasks');
  assert.match(FUN, /users=\(owner member reader stranger\);/);
  assert.match(FUN, /user_owner_role='Manager' ;\n\s+user_member_role='Developer' ;\n\s+user_reader_role='Reporter' ;\n\s+user_stranger_role='' ;/);
  assert.doesNotMatch(FUN, /ddev stop -y/, 'ddev stop takes no -y');
  const connect = FUN.slice(FUN.indexOf('function redmine_connect()'), FUN.indexOf('function redmine_cli_tool()'));
  assert.match(connect, /REDMINE_NEW_TOKEN="\$\{token\}" python3/, 'the key reaches the settings writer in its environment only');
  assert.match(connect, /0o600/, 'the settings file stays readable by its owner only');
  assert.doesNotMatch(connect, /echo[^\n]*\$\{token\}/, 'the key is never printed');
});

test('the assistant is told how to build, test and connect a site', () => {
  const told = assistantContext();
  for (const c of COMMANDS) assert.ok(told.includes(c), `the assistant is told about ${c}`);
  for (const a of AGENTS) assert.ok(told.includes(a), `the assistant is told about ${a}`);
  assert.match(told, /with `--runtime docker`, `podman` or `kubernetes` at the address the runtime gives it/);
  assert.match(told, /--connect <login>/);
});

test('the docs say container-based, name only what ships, and carry no personal value', () => {
  const docs = ['README.md', ...manifest.ai.agents, 'scripts/functions/fun-redmine.sh', 'config/plugin.redmine.settings.yml'];
  for (const f of docs) {
    const src = read(f);
    assert.doesNotMatch(src, /DDEV-only/i, `${f}: the workspace is container-based, DDEV by default`);
    assert.doesNotMatch(src, /\/home\/(?!YOUR_USER)[a-z]/, `${f} carries no personal path`);
    const mails = src.match(/[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[a-z]{2,}/g) || [];
    for (const m of mails) assert.match(m, /@example\.(com|org)$/, `${f}: ${m} is not an example address`);
  }
  for (const c of COMMANDS) assert.ok(read('README.md').includes(c), `the README lists ${c}`);
  const keys = [...read('config/plugin.redmine.settings.yml').matchAll(/^([a-z_]+):/gm)].map((m) => m[1]);
  assert.ok(keys.length >= 12);
  for (const k of keys) assert.ok(read('README.md').includes(`\`${k}\``), `the README describes the setting ${k}`);
});

test('the testing setup writes the accounts and the sample content in the project, and says which part did not work', () => {
  const testing = FUN.slice(FUN.indexOf('function testing_configure_redmine()'));
  // add_redmine_users ends in the sites folder: the sample content is asked for in the project again (#7).
  assert.match(FUN, /^function add_redmine_users\(\) \{[\s\S]*?\n  cd \$\{WORKSPACE_ROOT\}\/\$\{doc_name\};\n  return \$\{status\} ;\n\}/m);
  assert.match(testing, /elif ! \( cd "\$\{project_path\}" && add_redmine_users > \/dev\/null 2>&1 \) ; then/, 'the accounts, in the project');
  assert.match(testing, /elif ! \( cd "\$\{project_path\}" && redmine_site content < \/dev\/null > \/dev\/null 2>&1 \) ; then/, 'the sample content, in the project');
  assert.doesNotMatch(testing, /add_redmine_users[^\n]*&& redmine_site content/, 'never after add_redmine_users in one subshell, which ends in the sites folder');
  for (const said of ['does not answer', 'The default accounts could not be written', 'The sample content could not be written']) assert.ok(testing.includes(said), said);
});
