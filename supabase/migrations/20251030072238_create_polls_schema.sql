/*
  # Create Polls Schema

  1. New Tables
    - `polls`
      - `id` (uuid, primary key) - Unique poll identifier
      - `title` (text) - Poll title
      - `status` (text) - Poll status (NEW, ELABORATION, VOTING, FINISHED)
      - `admin_token` (uuid) - Secret token for admin access
      - `vote_token` (uuid) - Public token for voters
      - `admin_email` (text) - Email of poll creator
      - `num_voters` (integer) - Count of votes cast
      - `created_at` (timestamptz) - Creation timestamp
      - `updated_at` (timestamptz) - Last update timestamp
    
    - `proposals`
      - `id` (uuid, primary key) - Unique proposal identifier
      - `poll_id` (uuid, foreign key) - Reference to poll
      - `title` (text) - Proposal title
      - `sort_order` (integer) - Order in poll
      - `created_at` (timestamptz) - Creation timestamp
    
    - `votes`
      - `id` (uuid, primary key) - Unique vote identifier
      - `poll_id` (uuid, foreign key) - Reference to poll
      - `voter_id` (text) - Anonymous voter identifier (hashed)
      - `vote_order` (jsonb) - Array of proposal IDs in voter's preferred order
      - `created_at` (timestamptz) - Vote timestamp
  
  2. Security
    - Enable RLS on all tables
    - Polls accessible by admin token or vote token
    - Proposals readable by anyone with poll access
    - Votes can only be created once per voter per poll
  
  3. Indexes
    - Index on poll tokens for fast lookups
    - Index on poll_id for proposals and votes
*/

-- Create polls table
CREATE TABLE IF NOT EXISTS polls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  status text NOT NULL DEFAULT 'NEW',
  admin_token uuid NOT NULL DEFAULT gen_random_uuid(),
  vote_token uuid NOT NULL DEFAULT gen_random_uuid(),
  admin_email text NOT NULL,
  num_voters integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create proposals table
CREATE TABLE IF NOT EXISTS proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  title text NOT NULL,
  sort_order integer NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Create votes table
CREATE TABLE IF NOT EXISTS votes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  voter_id text NOT NULL,
  vote_order jsonb NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(poll_id, voter_id)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_polls_admin_token ON polls(admin_token);
CREATE INDEX IF NOT EXISTS idx_polls_vote_token ON polls(vote_token);
CREATE INDEX IF NOT EXISTS idx_proposals_poll_id ON proposals(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_poll_id ON votes(poll_id);
CREATE INDEX IF NOT EXISTS idx_votes_voter_id ON votes(poll_id, voter_id);

-- Enable Row Level Security
ALTER TABLE polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE proposals ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;

-- RLS Policies for polls table
CREATE POLICY "Anyone can create a poll"
  ON polls FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Admin can view their poll via admin_token"
  ON polls FOR SELECT
  TO anon
  USING (
    admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
    OR vote_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
  );

CREATE POLICY "Admin can update their poll via admin_token"
  ON polls FOR UPDATE
  TO anon
  USING (admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token')
  WITH CHECK (admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token');

-- RLS Policies for proposals table
CREATE POLICY "Anyone can view proposals for accessible polls"
  ON proposals FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = proposals.poll_id
      AND (
        polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
        OR polls.vote_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
      )
    )
  );

CREATE POLICY "Admin can insert proposals"
  ON proposals FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = proposals.poll_id
      AND polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
    )
  );

CREATE POLICY "Admin can update proposals"
  ON proposals FOR UPDATE
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = proposals.poll_id
      AND polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = proposals.poll_id
      AND polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
    )
  );

CREATE POLICY "Admin can delete proposals"
  ON proposals FOR DELETE
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = proposals.poll_id
      AND polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
    )
  );

-- RLS Policies for votes table
CREATE POLICY "Voters can view votes for accessible polls"
  ON votes FOR SELECT
  TO anon
  USING (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = votes.poll_id
      AND (
        polls.admin_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
        OR polls.vote_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
      )
    )
  );

CREATE POLICY "Voters can cast their vote"
  ON votes FOR INSERT
  TO anon
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM polls
      WHERE polls.id = votes.poll_id
      AND polls.vote_token::text = current_setting('request.jwt.claims', true)::json->>'poll_token'
      AND polls.status = 'VOTING'
    )
  );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger to auto-update updated_at
CREATE TRIGGER update_polls_updated_at BEFORE UPDATE ON polls
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
