# composex

composex composes live, data-driven surfaces (dashboards, reports and pages) out of independent parts, which share typed data and interactive state through one source contract. You declare the arrangement and the data flow in validated documents, and composex runs the surfaces per viewer on Phoenix LiveView: rendered on the server, safe under a strict security policy, and reproducible afterwards.

It is the shared layer beneath:

- **visualize**: charts and boards become components and surfaces;
- **metresis**: queries become data sources, and dashboards become components;
- **dcotek_web**: composable pages, with records for replay and one theme for the whole site.

## Status

Spec first. Nothing is implemented yet.

- [`spec/README.md`](spec/README.md): the draft model (sources, state sources, derived sources, components and cells, surfaces and regions, documents, records, stores, themes, registries, web rules), with the decisions still open.
- [`design/requirements/`](design/requirements/): the requirement reports it was derived from, one per project, collected against [`TEMPLATE.md`](design/requirements/TEMPLATE.md).

Changes go through proposals (GitLab issues): `Research` while a direction is being shaped, `Proposal` when it is ready to evaluate.
