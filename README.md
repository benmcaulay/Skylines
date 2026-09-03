# Skylines

Every flight you have ever taken, on one globe.

A flight log in the spirit of [OpenFlights](https://openflights.org) — a spinning
orthographic globe with great-circle arcs, per-airport stats, route and airline
analysis — with two things OpenFlights makes harder than they need to be:

- **Adding an airline is one field.** Type any part of a name or an IATA code and
  it searches 1,762 carriers. Your own airlines sort to the top. If nothing
  matches, the first option is *Use "…" · new airline* — no separate create step.
- **Round trips are one entry.** The add-flight form has a round-trip toggle on by
  default: one date out, one date back, and saving writes both segments with the
  return automatically reversed.

Accounts are optional. Signed out, everything lives in your browser. Signed in,
your flights sync to Postgres and follow you between devices.

## Stack

Static HTML, no build step, no framework. One `index.html` with the world
geometry and a 6,072-airport database inlined, `vendor/supabase.js` for auth and
storage. Deploys to Vercel as-is.

## Setup

### 1. Create the database

In your Supabase project: **SQL Editor → New query**, paste
[`supabase/schema.sql`](supabase/schema.sql), and run it. That creates:

- `public.flights` — one row per segment, with `user_id` referencing `auth.users`
- Row level security policies so a signed-in user can only ever read or write
  their own rows
- `public.profiles`, populated by a trigger on signup

The whole file is idempotent, so re-running it is safe.

### 2. Point the app at the project

Copy the **Project URL** and **anon public** key from Project Settings → API into
[`config.js`](config.js):

```js
window.SKYLINES_CONFIG = {
  SUPABASE_URL: 'https://yourproject.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGci...'
};
```

The anon key is meant to ship in the browser — RLS is what protects the data.
Never put the `service_role` key here.

You can also skip this file entirely and paste both values into the in-app setup
screen, which stores them in `localStorage` for that browser only. Useful for
trying it out; use `config.js` for a real deployment.

### 3. Auth settings

Email + password and magic links both work with Supabase's defaults, no provider
setup needed. Two things worth checking:

- **Authentication → URL Configuration** — set **Site URL** to your deployed
  origin and add it to **Redirect URLs**, or magic links will bounce.
- **Authentication → Providers → Email** — "Confirm email" is on by default. New
  accounts must click a confirmation link before their first sign-in. Turn it off
  if you want instant signup.

Supabase's built-in SMTP is rate limited to a handful of emails per hour. Wire up
your own SMTP under Project Settings → Auth before letting real users in.

### 4. Deploy

Live at **https://skylines-indol.vercel.app**, deployed automatically from
`main`. To set that up on your own fork, import the repo at
[vercel.com/new](https://vercel.com/new), or from a checkout:

```bash
vercel
```

Framework preset **Other**, no build command, output directory the repo root.
`vercel.json` sets cache and security headers; there is nothing to compile.

Two settings worth knowing about. Vercel enables **Deployment Protection** on
new projects, which puts a Vercel SSO login in front of every `.vercel.app` URL
— turn it off under Project Settings → Deployment Protection, or the site is
invisible to everyone but you.

And note that `cleanUrls` is deliberately **not** set. With no framework preset it
rewrites `/index.html` to `/` and then fails to resolve the root, so the site
404s on its own home page.

## Local use

Open `index.html` directly in a browser and it works — guest mode, all data in
`localStorage`. Email + password sign-in works from `file://` too; magic links do
not, since they need a real redirect origin. To run it over HTTP:

```bash
python3 -m http.server 8731
```

## Your data

Flights are stored one row per **segment**, so a round trip is two rows — the same
model OpenFlights uses, which keeps distances and per-airport counts honest.

- **↑ Import** reads an OpenFlights CSV export directly, and offers to replace or
  merge. Rows whose airports it cannot resolve are skipped and counted.
- **↓ Export** writes the same 15-column layout back out, so it round-trips with
  openflights.org.
- **⟲ Revert** replaces everything with the log bundled at build time.

Signing in on a browser that already has flights offers to upload them once, if
the account is empty.

## Rebuilding

`index.html` is generated. To change the app, edit `app.template.html` and run:

```bash
python3 build.py [path/to/openflights-export.csv]
```

That inlines three things into the template: `data/world.json` (Natural Earth
110m country polygons, delta-decoded from TopoJSON), `data/ref.json` (airports
and airlines from the OpenFlights database), and the seed log from the CSV.

### The bundled seed log

`data/seed.csv` is baked into `index.html` and is what signed-out visitors see.
It ships **empty**, so a fresh deployment starts with a bare globe and nobody's
travel history in the bundle. Your own flights belong in your account: sign in
and use **↑ Import** once.

To bundle a demo log instead — useful if you want the map to look alive for
visitors — point the build at any OpenFlights CSV:

```bash
python3 build.py path/to/export.csv
```

Anything you bundle this way is visible to everyone who opens the site or reads
the repo, so keep real personal history out of it.

## Licence and credits

Skylines is MIT licensed. Bundled data keeps its own terms — see [NOTICE](NOTICE).

Airport and airline reference data comes from the
[OpenFlights database](https://github.com/jpatokal/openflights), made available
under the [ODbL](https://opendatacommons.org/licenses/odbl/1-0/); OpenFlights in
turn sources airport records from OurAirports. Country geometry is
[Natural Earth](https://www.naturalearthdata.com/) via
[world-atlas](https://github.com/topojson/world-atlas), public domain.
