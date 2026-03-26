import { createClient } from '@supabase/supabase-js';

const supabaseUrl = 'https://oqcmbgtpqjzfscymnije.supabase.co';
const supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9xY21iZ3RwcWp6ZnNjeW1uaWplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0NzYwMzgsImV4cCI6MjA5MDA1MjAzOH0.7DUCw6ZloZ1DASnxWjeQivk8Jij5NYORtZR-sdigZ94';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);
