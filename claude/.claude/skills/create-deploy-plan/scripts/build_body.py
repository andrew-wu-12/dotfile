#!/usr/bin/env python3
"""Build the storage-format body for a MOP deploy plan page.

Every deploy plan this skill makes is a frontend-monorepo deploy, so the
structure is fixed: a short pre-publish checklist, then one section per
environment stage (one-dev -> one-uat -> one), then Tickets and Deployments.
The only things that vary per deploy are the epic ticket and two optional
prod-stage steps (backend publish, config-file deploy) — those are flags.

Task ids are assigned sequentially here and Confluence reassigns them on save;
we number them anyway so the created page is valid on the first POST.

Usage:
  build_body.py <EPIC_KEY> [--be-publish] [--config-deploy] > body.xml
"""
import argparse

GREY = "rgb(151,160,175)"
JIRA_SERVER_ID = "b042f398-439a-3c26-bf49-d230a46a4f8f"
MONOREPO = "mop-console-monorepo"
CONFIG_REPO = "mop_configuration_files"

# The standard checklist that gates publishing the plan itself.
PREPUBLISH = ["Dry Run Plan with BA/SA", "SA - Check Jira Status"]


def stage_tasks(env):
    """Deploy + verify the monorepo in one environment."""
    return [
        f"Deploy <code>{MONOREPO}</code> to {env}",
        f"Test module in <code>{MONOREPO}</code> ( i.e. Affected APPs )",
    ]


class Counter:
    def __init__(self):
        self.n = 0

    def next(self):
        self.n += 1
        return self.n


def task(label, ctr):
    i = ctr.next()
    return (
        f"<ac:task><ac:task-id>{i}</ac:task-id>"
        f"<ac:task-uuid>{i}</ac:task-uuid>"
        f"<ac:task-status>incomplete</ac:task-status>"
        f'<ac:task-body><span class="placeholder-inline-tasks">{label}</span>'
        f"</ac:task-body></ac:task>"
    )


def task_list(labels, ctr):
    return "<ac:task-list>" + "".join(task(l, ctr) for l in labels) + "</ac:task-list>"


def section(title, labels, ctr):
    return f"<h2>{title}</h2>" + task_list(labels, ctr)


def grey(text):
    return f'<span style="color: {GREY};">{text}</span>'


def jira_macro(key):
    return (
        '<ac:structured-macro ac:name="jira" ac:schema-version="1">'
        f'<ac:parameter ac:name="key">{key}</ac:parameter>'
        f'<ac:parameter ac:name="serverId">{JIRA_SERVER_ID}</ac:parameter>'
        '<ac:parameter ac:name="server">System Jira</ac:parameter>'
        "</ac:structured-macro>"
    )


def deploy_row(project):
    """A pre-filled Deployments row: only the Git Project cell is set."""
    cells = [f"<p>{project}</p>"] + ["<p />"] * 5
    return "<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>"


def deployments_table(config_deploy):
    headers = ["Git Project", "Version", "Deploy Start", "Deploy End",
               "Developer(s)", "Executor"]
    header_row = "<tr>" + "".join(
        f"<th><p><strong>{h}</strong></p></th>" for h in headers) + "</tr>"
    guidance_cells = [
        f"<p>{grey('Git project name')}</p>",
        f"<p>{grey('Git tag')}</p>",
        f"<p>{grey('start time (UTC+8)')}</p><p>{grey('fill this field when the deploy ')}"
        f"<strong>{grey('starts')}</strong></p>",
        f"<p>{grey('end time (UTC+8)')}</p><p>{grey('fill this field when the deploy ')}"
        f"<strong>{grey('ends')}</strong></p>",
        f"<p>{grey('developer list')}</p>",
        f"<p>{grey('who trigger the Jenkins job')}</p>",
    ]
    guidance_row = "<tr>" + "".join(f"<td>{c}</td>" for c in guidance_cells) + "</tr>"
    rows = [header_row, guidance_row, deploy_row(MONOREPO)]
    if config_deploy:
        rows.append(deploy_row(CONFIG_REPO))
    colgroup = (
        "<colgroup>"
        '<col style="width: 150.0px;" /><col style="width: 102.0px;" />'
        '<col style="width: 126.0px;" /><col style="width: 118.0px;" />'
        '<col style="width: 133.0px;" /><col style="width: 126.0px;" />'
        "</colgroup>"
    )
    return (
        '<table data-table-width="760" data-layout="default">'
        + colgroup + "<tbody>" + "".join(rows) + "</tbody></table>"
    )


def build(epic_key, be_publish, config_deploy):
    ctr = Counter()
    # Prod-stage optional steps come before the monorepo deploy, matching the
    # order a release actually runs them (backend + config land first).
    one_labels = []
    if be_publish:
        one_labels.append("BE - Publish")
    if config_deploy:
        one_labels.append(f"Deploy <code>{CONFIG_REPO}</code> to one")
    one_labels += stage_tasks("one")

    parts = [
        "<p>You should check the following items before publish this deploy plan.</p>",
        task_list(PREPUBLISH, ctr),
        section("one-dev", stage_tasks("one-dev"), ctr),
        section("one-uat", stage_tasks("one-uat"), ctr),
        section("one", one_labels, ctr),
        "<hr />",
        "<h2>Tickets</h2>",
        f"<p>{grey('The actual feature/issue ticket links.')}</p>",
        f"<p>{jira_macro(epic_key)}</p>",
        "<h2>Deployments</h2>",
        f"<p>{grey('Projects to be deployed.')}</p>",
        deployments_table(config_deploy),
    ]
    return "".join(parts)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("epic_key")
    ap.add_argument("--be-publish", action="store_true",
                    help="include 'BE - Publish' in the one (prod) stage")
    ap.add_argument("--config-deploy", action="store_true",
                    help="include the mop_configuration_files deploy task + table row")
    a = ap.parse_args()
    print(build(a.epic_key, a.be_publish, a.config_deploy))


if __name__ == "__main__":
    main()
