class_name AppConfig
## Where the app talks to. It is the same Supabase project as the site, so an
## account made there works here. The anon key is public by design: row-level
## security decides what it may read or write.

const SUPABASE_URL := "https://fryktaphslwtijruymgk.supabase.co"
const SUPABASE_ANON_KEY := "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZyeWt0YXBoc2x3dGlqcnV5bWdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjA2NTIsImV4cCI6MjEwNDI5NjY1Mn0.nEs7FOvkRXakvuGJbHzgBx631Kdv39cxfPB7RRxeaS4"

const SITE_URL := "https://txmmytwostraps.github.io/gdscript-practice/"

## GitHub sign-in happens in the phone's browser. When GitHub is done, the
## browser is sent to this address, which the app itself answers: it listens
## on that port for a moment. The address must be on the Supabase project's
## list of allowed redirect URLs.
const OAUTH_PORT := 41337
const OAUTH_REDIRECT := "http://127.0.0.1:41337/callback"
