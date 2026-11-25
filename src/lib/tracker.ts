/**
 * Redmine, as a provider of the tracker family (@webship.co/workspace-tracker): the issues of a Redmine project, over
 * its REST API with an API key (the X-Redmine-API-Key header), in a header file, never on a command line.
 *
 * Reads: the open issues, mine, assigned to someone, the current version, and a search in the subject; one issue with
 * its notes. Each author's standing is their membership of the project: a Manager and a Developer are inside; a
 * Reporter, another role, and someone with no membership are outside, so the base keeps their issues analyze-only
 * unless a person confirms by name.
 *
 * Writes, which the base offers only with writes on, each after a person's click: a note, a time entry, a status the
 * workflow allows, an assignee, and a new issue. Redmine is not a forge: the pull request of the work is opened from the
 * project's forge menu. A Redmine API key is 40 hex digits, the shape of a git commit too, so it has no token shape of
 * its own here: the base still refuses this site's own key wherever it is.
 */

import fs from 'fs';
import os from 'os';
import path from 'path';
import type { PluginApi } from '@webship.co/workspace-plugin-api';
import type { Person, TrackerItem, TrackerItemFull, TrackerProvider, TrackerScope, WriteResult } from '@webship.co/workspace-tracker';

const SCOPE_RE = /^[a-z][a-z0-9_-]{0,99}$/;
const configured = (v: unknown) => { const s = String(v == null ? '' : v).trim(); return s && s !== 'CHANGE_ME' ? s : ''; };

/** A project role, as the base reads an author's standing. */
export function roleAssociation(roles: string[]): Person['association'] {
  if (roles.some((r) => /^manager$/i.test(r))) return 'owner';
  if (roles.some((r) => /^developer$/i.test(r))) return 'member';
  return roles.length ? 'contributor' : 'outside';
}

/** How a status reads: a closed one (Closed, Rejected, Resolved) is done; New is open; the rest is work going on. */
export function stateClassOf(status: { name?: string; is_closed?: boolean } | undefined): TrackerItem['stateClass'] {
  if (!status) return undefined;
  if (status.is_closed || /^(closed|rejected|resolved)$/i.test(String(status.name || ''))) return 'done';
  if (/^new$/i.test(String(status.name || ''))) return 'open';
  return 'doing';
}

/** An issue of the API, as the base reads an item. */
export function itemOf(issue: any, base: string): TrackerItem {
  return {
    id: String(issue.id),
    title: String(issue.subject || ''),
    url: `${base}/issues/${issue.id}`,
    state: String((issue.status && issue.status.name) || ''),
    stateClass: stateClassOf(issue.status),
    type: issue.tracker && issue.tracker.name ? String(issue.tracker.name) : undefined,
    assignees: issue.assigned_to && issue.assigned_to.name ? [String(issue.assigned_to.name)] : [],
    labels: issue.category && issue.category.name ? [String(issue.category.name)] : [],
    iteration: issue.fixed_version && issue.fixed_version.name ? `version ${issue.fixed_version.name}` : undefined,
    updated: issue.updated_on || undefined,
  };
}

/** The version a "current version" view means: the open one due first from today, else the open one with no date. */
export function currentVersion(list: any[], now = new Date()): string {
  const day = now.toISOString().slice(0, 10);
  const open = (list || []).filter((v) => v && v.id && String(v.status || 'open') === 'open');
  const dated = open.filter((v) => v.due_date && v.due_date >= day).sort((a, b) => String(a.due_date).localeCompare(String(b.due_date)));
  if (dated.length) return String(dated[0].id);
  const undated = open.find((v) => !v.due_date);
  return undated ? String(undated.id) : '';
}

export function redmineTracker(api: PluginApi): TrackerProvider {
  const lib = api.lib;
  const settings = () => api.settings.read() || {};
  const base = () => configured(settings().url).replace(/\/+$/, '');
  const token = () => configured(settings().token);

  /** One call of the REST API: the key and the body in files only this user reads, removed after. */
  async function call(method: string, p: string, body?: unknown): Promise<{ status: number; data: any }> {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'ws-redmine-'));
    try {
      const h = path.join(dir, 'headers');
      fs.writeFileSync(h, `X-Redmine-API-Key: ${token()}\nAccept: application/json\n`, { mode: 0o600 });
      const args = ['-sS', '-m', '30', '-X', method, '-w', '\n%{http_code}', '-H', `@${h}`];
      if (body !== undefined) {
        const b = path.join(dir, 'body.json');
        fs.writeFileSync(b, JSON.stringify(body), { mode: 0o600 });
        args.push('-H', 'Content-Type: application/json', '--data-binary', `@${b}`);
      }
      args.push(`${base()}${p}`);
      const r = await lib.run('curl', args, process.env.HOME || '/', { timeoutMs: 40 * 1000, env: process.env });
      const out = String(r.stdout || '');
      const at = out.lastIndexOf('\n');
      const status = Number(out.slice(at + 1)) || 0;
      if (!status) throw new Error(lib.cliError(String(r.stderr || 'curl did not answer')));
      let data: any = null;
      try { data = JSON.parse(at >= 0 ? out.slice(0, at) : out); } catch (_) { data = null; }
      return { status, data };
    } finally { fs.rmSync(dir, { recursive: true, force: true }); }
  }
  const why = (r: { status: number; data: any }) => `Redmine answered ${r.status}${r.data && Array.isArray(r.data.errors) && r.data.errors.length ? `: ${r.data.errors.join('; ').slice(0, 200)}` : ''}`;
  async function get(p: string): Promise<any> {
    const r = await call('GET', p);
    if (r.status < 200 || r.status >= 300) throw new Error(why(r));
    return r.data;
  }
  async function write(method: string, p: string, body: unknown, url: string): Promise<WriteResult & { data?: any }> {
    try {
      const r = await call(method, p, body);
      return r.status >= 200 && r.status < 300 ? { ok: true, error: '', url, data: r.data } : { ok: false, error: why(r) };
    } catch (e) { return { ok: false, error: String((e as Error).message || e) }; }
  }

  const projectIds = new Map<string, string>();
  async function projectId(scope: TrackerScope): Promise<string> {
    if (!projectIds.has(scope.id)) projectIds.set(scope.id, String((await get(`/projects/${encodeURIComponent(scope.id)}.json`)).project.id));
    return projectIds.get(scope.id) as string;
  }

  // The members of a project and their roles, asked once per project for a few minutes (every page of them).
  const memberships = new Map<string, { at: number; members: Map<string, { name: string; roles: string[] }> | null }>();
  async function membersOf(scope: TrackerScope): Promise<Map<string, { name: string; roles: string[] }> | null> {
    const hit = memberships.get(scope.id);
    if (hit && Date.now() - hit.at < 5 * 60 * 1000) return hit.members;
    let members: Map<string, { name: string; roles: string[] }> | null = new Map();
    try {
      for (let offset = 0; offset < 1000; offset += 100) {
        const d = await get(`/projects/${encodeURIComponent(scope.id)}/memberships.json?limit=100&offset=${offset}`);
        const list: any[] = (d && d.memberships) || [];
        for (const m of list) {
          if (!m.user) continue; // a group's membership
          const uid = String(m.user.id);
          const now = members.get(uid) || { name: String(m.user.name || ''), roles: [] };
          now.roles.push(...((m.roles || []) as any[]).map((r) => String(r.name || '')));
          members.set(uid, now);
        }
        if (list.length < 100) break;
      }
    } catch (_) { members = null; }
    memberships.set(scope.id, { at: Date.now(), members });
    return members;
  }
  async function personOf(scope: TrackerScope, who: any): Promise<Person> {
    const name = String((who && who.name) || 'unknown');
    const uid = who && who.id != null ? String(who.id) : '';
    if (!uid) return { name, association: 'unknown' };
    const members = await membersOf(scope);
    if (!members) return { name, association: 'unknown' };
    return { name, association: roleAssociation((members.get(uid) || { roles: [] }).roles) };
  }
  /**
   * Someone who can be assigned in the project: "me", the key's own login, a member's user id, a member's whole name
   * ("Member Test") or its first word ("owner" for "Owner Test"): their id. Only an administrator may read the other
   * members' logins, so a member is found by what the project's member list shows.
   */
  async function assigneeId(scope: TrackerScope, who: string): Promise<string> {
    const w = who.trim().toLowerCase();
    const me = await get('/users/current.json').catch(() => null);
    if (w === 'me' || (me && me.user && String(me.user.login || '').toLowerCase() === w)) {
      if (me && me.user) return String(me.user.id);
    }
    const members = [...((await membersOf(scope)) || new Map()).entries()];
    const found = members.find(([uid]) => uid === w)
      || members.find(([, m]) => m.name.toLowerCase() === w)
      || members.find(([, m]) => m.name.toLowerCase().split(/\s+/)[0] === w);
    if (found) return found[0];
    throw new Error(`${who} is no member of the project who takes issues`);
  }

  const issueUrl = (id: string) => `${base()}/issues/${id}`;

  return {
    id: api.name,
    title: 'Redmine',
    label: 'REDMINE',
    noun: { one: 'issue', many: 'issues' },
    capabilities: {
      views: ['open', 'mine', 'assigned', 'iteration', 'query'],
      iterationWord: 'version',
      comment: true, worklog: true, transition: true, labels: false, assign: true, create: true,
      request: 'none',
    },
    idPattern: /^[1-9][0-9]{0,9}$/,
    tokenVariables: ['REDMINE_API_KEY', 'REDMINE_TOKEN'],
    secret: () => token(),
    ready: () => (!base() ? `no Redmine address in ${api.settings.file} (url)` : !token() ? `no API key in ${api.settings.file} (token)` : ''),
    // A workspace project has no Redmine project of its own: it remembers one, or the default is used.
    scopeOf: () => null,
    parseScope: (text) => {
      const t = String(text || '').trim();
      return SCOPE_RE.test(t) && base() ? { id: t, name: t, web: `${base()}/projects/${t}` } : null;
    },
    urlOf: (_s, id) => issueUrl(id),
    account: async () => { try { return String((await get('/users/current.json')).user.login || ''); } catch (_) { return ''; } },
    scopes: async () => {
      const d = await get('/projects.json?limit=100');
      return ((d && d.projects) || []).filter((x: any) => x.identifier && SCOPE_RE.test(String(x.identifier)))
        .map((x: any) => ({ id: String(x.identifier), name: String(x.name || x.identifier), web: `${base()}/projects/${x.identifier}` }));
    },

    list: async (scope, q) => {
      const p = new URLSearchParams({ project_id: await projectId(scope), status_id: 'open', sort: 'updated_on:desc', limit: String(Math.max(1, Math.min(q.limit, 100))) });
      if (q.view === 'mine') p.set('assigned_to_id', 'me');
      if (q.view === 'assigned') { if (!q.who) return []; p.set('assigned_to_id', await assigneeId(scope, q.who)); }
      if (q.view === 'iteration') {
        const v = currentVersion(((await get(`/projects/${encodeURIComponent(scope.id)}/versions.json`)) || {}).versions || []);
        if (!v) return [];
        p.set('fixed_version_id', v);
      }
      if (q.view === 'query') p.set('subject', `~${String(q.text || '')}`);
      const d = await get(`/issues.json?${p.toString()}`);
      return ((d && d.issues) || []).map((i: any) => itemOf(i, base()));
    },

    get: async (scope, id) => {
      const d = await get(`/issues/${id}.json?include=journals`);
      const issue = d.issue || {};
      const author = await personOf(scope, issue.author);
      const journals: any[] = issue.journals || [];
      // The description's last editor: the newest journal that changed it, when it is not the author.
      let lastEditor: Person | undefined;
      const edit = [...journals].reverse().find((j) => (j.details || []).some((x: any) => x.property === 'attr' && x.name === 'description'));
      if (edit && edit.user && String(edit.user.id) !== String(issue.author && issue.author.id)) lastEditor = await personOf(scope, edit.user);
      const comments = [];
      for (const j of journals) {
        const raw = String(j.notes || '').trim();
        if (!raw || j.private_notes) continue;
        comments.push({ author: await personOf(scope, j.user), body: raw, at: String(j.created_on || '') });
      }
      const full: TrackerItemFull = { ...itemOf(issue, base()), body: String(issue.description || ''), author, ...(lastEditor ? { lastEditor } : {}), comments };
      return full;
    },

    comment: async (_scope, id, markdown) => write('PUT', `/issues/${id}.json`, { issue: { notes: markdown } }, issueUrl(id)),
    worklog: async (_scope, id, entry) => {
      // The site's default activity, else its first: a time entry needs one.
      let activity = '';
      try {
        const list: any[] = ((await get('/enumerations/time_entry_activities.json')) || {}).time_entry_activities || [];
        const pick = list.find((a) => a.is_default) || list.find((a) => a.active !== false);
        activity = pick ? String(pick.id) : '';
      } catch (_) { activity = ''; }
      return write('POST', '/time_entries.json', {
        time_entry: { issue_id: Number(id), hours: Math.round((entry.minutes / 60) * 100) / 100, comments: entry.text, ...(activity ? { activity_id: Number(activity) } : {}) },
      }, issueUrl(id));
    },
    transitions: async (_scope, id) => {
      const d = await get(`/issues/${id}.json?include=allowed_statuses`);
      const now = String((d.issue && d.issue.status && d.issue.status.id) || '');
      return ((d.issue && d.issue.allowed_statuses) || [] as any[]).filter((s: any) => String(s.id) !== now).map((s: any) => ({ id: String(s.id), name: String(s.name) }));
    },
    transition: async (_scope, id, to) => {
      if (!/^\d+$/.test(to)) return { ok: false, error: `not a status: ${to}` };
      return write('PUT', `/issues/${id}.json`, { issue: { status_id: Number(to) } }, issueUrl(id));
    },
    assign: async (scope, id, whom) => {
      let uid = '';
      try { uid = await assigneeId(scope, whom); } catch (e) { return { ok: false, error: String((e as Error).message || e) }; }
      return write('PUT', `/issues/${id}.json`, { issue: { assigned_to_id: Number(uid) } }, issueUrl(id));
    },
    create: async (scope, item) => {
      const r = await write('POST', '/issues.json', { issue: { project_id: Number(await projectId(scope)), subject: item.title, description: item.body } }, '');
      const nid = String(r.data && r.data.issue && r.data.issue.id);
      return r.ok ? { ok: true, error: '', id: nid, url: issueUrl(nid) } : r;
    },
  };
}
