BEGIN;

DROP SCHEMA IF EXISTS campaign_app CASCADE;
CREATE SCHEMA campaign_app;
SET search_path = campaign_app, public;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_enum') THEN
    CREATE TYPE status_enum AS ENUM ('planned','confirmed','done','canceled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'channel_enum') THEN
    CREATE TYPE channel_enum AS ENUM ('phone','field','online');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'sentiment_enum') THEN
    CREATE TYPE sentiment_enum AS ENUM ('pos','neu','neg');
  END IF;
END$$;

CREATE TABLE campaign (
  campaign_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name           VARCHAR(200) NOT NULL,
  election_level VARCHAR(40)  NOT NULL,
  start_date     DATE NOT NULL,
  end_date       DATE,
  CONSTRAINT uq_campaign_name UNIQUE (name),
  CONSTRAINT ck_campaign_start_date CHECK (start_date > DATE '2000-01-01'),
  CONSTRAINT ck_campaign_dates_order CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE TABLE person (
  person_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  first_name  VARCHAR(80)  NOT NULL,
  last_name   VARCHAR(80)  NOT NULL,
  phone       VARCHAR(40),
  email       VARCHAR(255) UNIQUE,
  street      VARCHAR(120),
  city        VARCHAR(80),
  region      VARCHAR(80),
  postal_code VARCHAR(20),
  country     VARCHAR(80),
  full_name   TEXT GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED
);

CREATE TABLE voter (
  voter_id              BIGINT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
  voter_registration_no VARCHAR(80),
  birth_date            DATE,
  party_affiliation     VARCHAR(40),
  precinct              VARCHAR(80),
  CONSTRAINT ck_voter_birth CHECK (birth_date IS NULL OR birth_date > DATE '1900-01-01')
);

CREATE TABLE donor (
  donor_id          BIGINT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
  donor_type        VARCHAR(20)  NOT NULL,
  organization_name VARCHAR(200),
  tax_id            VARCHAR(40)
);

CREATE TABLE volunteer (
  volunteer_id BIGINT PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
  availability VARCHAR(200),
  skills       VARCHAR(200),
  is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE event (
  event_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id     BIGINT NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  parent_event_id BIGINT REFERENCES event(event_id) ON DELETE SET NULL,
  event_type      VARCHAR(40) NOT NULL,
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ,
  venue_name      VARCHAR(120),
  venue_street    VARCHAR(120),
  venue_city      VARCHAR(80),
  venue_region    VARCHAR(80),
  venue_postal    VARCHAR(20),
  venue_country   VARCHAR(80),
  duration_hours  NUMERIC(8,2) GENERATED ALWAYS AS (
                     GREATEST(0, EXTRACT(EPOCH FROM (COALESCE(ends_at, starts_at) - starts_at))/3600.0)
                   ) STORED,
  CONSTRAINT ck_event_start CHECK (starts_at::date > DATE '2000-01-01'),
  CONSTRAINT ck_event_time_order CHECK (ends_at IS NULL OR ends_at >= starts_at),
  CONSTRAINT uq_event_nat UNIQUE (campaign_id, event_type, starts_at)
);

CREATE TABLE survey (
  survey_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id BIGINT NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  title       VARCHAR(200) NOT NULL,
  channel     channel_enum NOT NULL,
  start_date  DATE NOT NULL,
  end_date    DATE,
  CONSTRAINT ck_survey_start CHECK (start_date > DATE '2000-01-01'),
  CONSTRAINT ck_survey_dates_order CHECK (end_date IS NULL OR end_date >= start_date),
  CONSTRAINT uq_survey UNIQUE (campaign_id, title)
);

CREATE TABLE survey_question (
  question_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  survey_id     BIGINT NOT NULL REFERENCES survey(survey_id) ON DELETE CASCADE,
  question_text TEXT NOT NULL,
  question_type VARCHAR(20) NOT NULL,
  position      INT NOT NULL,
  CONSTRAINT uq_survey_q UNIQUE (survey_id, position)
);

CREATE TABLE contribution (
  contribution_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id       BIGINT NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  donor_id          BIGINT NOT NULL REFERENCES donor(donor_id) ON DELETE RESTRICT,
  event_id          BIGINT REFERENCES event(event_id) ON DELETE SET NULL,
  contribution_date DATE  NOT NULL,
  amount            NUMERIC(12,2) NOT NULL,
  currency          VARCHAR(3) NOT NULL,
  method            VARCHAR(20) NOT NULL,
  purpose           VARCHAR(80),
  receipt_no        VARCHAR(60),
  CONSTRAINT ck_contrib_date CHECK (contribution_date > DATE '2000-01-01'),
  CONSTRAINT ck_contrib_amount CHECK (amount > 0),
  CONSTRAINT uq_contrib UNIQUE (campaign_id, donor_id, contribution_date, amount, method)
);

CREATE TABLE finance_expense (
  expense_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id  BIGINT NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  expense_date DATE  NOT NULL,
  amount       NUMERIC(12,2) NOT NULL,
  currency     VARCHAR(3) NOT NULL,
  category     VARCHAR(40) NOT NULL,
  vendor_name  VARCHAR(200),
  memo         TEXT,
  CONSTRAINT ck_exp_date CHECK (expense_date > DATE '2000-01-01'),
  CONSTRAINT ck_exp_amount CHECK (amount >= 0)
);

CREATE TABLE problem_report (
  problem_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  campaign_id BIGINT NOT NULL REFERENCES campaign(campaign_id) ON DELETE CASCADE,
  category    VARCHAR(40) NOT NULL,
  severity    VARCHAR(10) NOT NULL,
  description TEXT,
  reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status      VARCHAR(20) NOT NULL DEFAULT 'open',
  CONSTRAINT ck_problem_reported CHECK (reported_at::date > DATE '2000-01-01')
);

CREATE TABLE social_interaction (
  interaction_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id         BIGINT NOT NULL REFERENCES event(event_id) ON DELETE CASCADE,
  voter_id         BIGINT REFERENCES voter(voter_id) ON DELETE SET NULL,
  platform         VARCHAR(20) NOT NULL,
  occurred_at      TIMESTAMPTZ NOT NULL,
  interaction_type VARCHAR(20) NOT NULL,
  sentiment        sentiment_enum,
  permalink        TEXT,
  CONSTRAINT ck_social_time CHECK (occurred_at::date > DATE '2000-01-01')
);

CREATE TABLE event_assignment (
  assignment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id      BIGINT NOT NULL REFERENCES event(event_id) ON DELETE CASCADE,
  volunteer_id  BIGINT NOT NULL REFERENCES volunteer(volunteer_id) ON DELETE CASCADE,
  role_name     VARCHAR(40) NOT NULL,
  task_details  TEXT,
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  status        status_enum NOT NULL DEFAULT 'planned',
  CONSTRAINT uq_event_assignment UNIQUE (event_id, volunteer_id, role_name)
);

CREATE TABLE event_attendance (
  attendance_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_id        BIGINT NOT NULL REFERENCES event(event_id) ON DELETE CASCADE,
  voter_id        BIGINT NOT NULL REFERENCES voter(voter_id) ON DELETE CASCADE,
  checked_in_at   TIMESTAMPTZ,
  attendance_type VARCHAR(20),
  CONSTRAINT uq_event_att UNIQUE (event_id, voter_id)
);

CREATE TABLE survey_response (
  response_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  survey_id    BIGINT NOT NULL REFERENCES survey(survey_id) ON DELETE CASCADE,
  question_id  BIGINT NOT NULL REFERENCES survey_question(question_id) ON DELETE CASCADE,
  voter_id     BIGINT NOT NULL REFERENCES voter(voter_id) ON DELETE CASCADE,
  responded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  answer_text  TEXT,
  answer_code  VARCHAR(40),
  CONSTRAINT uq_survey_resp UNIQUE (survey_id, question_id, voter_id),
  CONSTRAINT ck_resp_time CHECK (responded_at::date > DATE '2000-01-01')
);

CREATE INDEX ix_event_campaign        ON event(campaign_id);
CREATE INDEX ix_contribution_campaign ON contribution(campaign_id);
CREATE INDEX ix_expense_campaign      ON finance_expense(campaign_id);
CREATE INDEX ix_assignment_event      ON event_assignment(event_id);
CREATE INDEX ix_attendance_event      ON event_attendance(event_id);
CREATE INDEX ix_response_question     ON survey_response(question_id);

-- Sample data

WITH ins AS (
  INSERT INTO campaign (name, election_level, start_date, end_date)
  VALUES
    ('City 2026 Mayoral', 'city',  DATE '2025-09-01', DATE '2026-06-30'),
    ('State 2026 Senate', 'state', DATE '2025-08-15', DATE '2026-11-30')
  ON CONFLICT (name) DO NOTHING
  RETURNING 1
) SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH ins AS (
  INSERT INTO person (first_name,last_name,phone,email,city,country)
  VALUES
    ('Alice','Wong','+1-555-1001','alice@ex.org','Springfield','USA'),
    ('Bob','Lopez','+1-555-1002','bob@ex.org','Springfield','USA'),
    ('Carol','Diaz','+1-555-1003','carol@ex.org','Austin','USA'),
    ('Dan','Ng','+1-555-1004','dan@ex.org','Austin','USA'),
    ('Eva','Kim','+1-555-1005','eva@ex.org','Boston','USA'),
    ('Fred','Miller','+1-555-1006','fred@ex.org','Boston','USA')
  ON CONFLICT (email) DO NOTHING
  RETURNING 1
) SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

INSERT INTO voter (voter_id, voter_registration_no, birth_date, party_affiliation, precinct)
SELECT p.person_id, 'REG-'||p.person_id, DATE '1990-01-01', 'independent', 'P-01'
FROM person p WHERE p.email IN ('alice@ex.org','bob@ex.org')
ON CONFLICT (voter_id) DO NOTHING;

INSERT INTO donor (donor_id, donor_type, organization_name, tax_id)
SELECT p.person_id,
       CASE WHEN p.email IN ('carol@ex.org','dan@ex.org') THEN 'individual' ELSE 'org' END,
       CASE WHEN p.email IN ('carol@ex.org','dan@ex.org') THEN NULL ELSE 'ACME Corp' END,
       CASE WHEN p.email IN ('carol@ex.org','dan@ex.org') THEN NULL ELSE '99-1234567' END
FROM person p WHERE p.email IN ('carol@ex.org','dan@ex.org')
ON CONFLICT (donor_id) DO NOTHING;

INSERT INTO volunteer (volunteer_id, availability, skills, is_active)
SELECT p.person_id, 'weekends', 'marshall,driver', TRUE
FROM person p WHERE p.email IN ('eva@ex.org','fred@ex.org')
ON CONFLICT (volunteer_id) DO NOTHING;

WITH c AS (
  SELECT campaign_id, name FROM campaign
  WHERE name IN ('City 2026 Mayoral','State 2026 Senate')
),
ins AS (
  INSERT INTO event (campaign_id, parent_event_id, event_type, starts_at, ends_at,
                     venue_name, venue_city, venue_country)
  SELECT (SELECT campaign_id FROM c WHERE name='City 2026 Mayoral'),
         NULL::BIGINT,
         'rally',
         TIMESTAMPTZ '2026-02-01 10:00+00', TIMESTAMPTZ '2026-02-01 12:00+00',
         'Central Park','Springfield','USA'
  UNION ALL
  SELECT (SELECT campaign_id FROM c WHERE name='City 2026 Mayoral'),
         NULL::BIGINT,
         'town_hall',
         TIMESTAMPTZ '2026-03-05 18:00+00', TIMESTAMPTZ '2026-03-05 19:30+00',
         'City Hall','Springfield','USA'
  UNION ALL
  SELECT (SELECT campaign_id FROM c WHERE name='State 2026 Senate'),
         NULL::BIGINT,
         'rally',
         TIMESTAMPTZ '2026-01-15 09:00+00', TIMESTAMPTZ '2026-01-15 10:30+00',
         'Capitol Steps','Austin','USA'
  ON CONFLICT (campaign_id, event_type, starts_at) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH v AS (
  SELECT v.volunteer_id, p.email
  FROM volunteer v
  JOIN person   p ON p.person_id = v.volunteer_id
),
e AS (SELECT event_id, event_type FROM event),
ins AS (
  INSERT INTO event_assignment (event_id, volunteer_id, role_name, task_details, status)
  SELECT (SELECT event_id FROM e WHERE event_type='rally'  LIMIT 1),
         (SELECT volunteer_id FROM v WHERE email='eva@ex.org'),
         'marshal','stage left','confirmed'::status_enum
  UNION ALL
  SELECT (SELECT event_id FROM e WHERE event_type='town_hall' LIMIT 1),
         (SELECT volunteer_id FROM v WHERE email='fred@ex.org'),
         'usher','entry control','planned'::status_enum
  ON CONFLICT (event_id, volunteer_id, role_name) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH vt AS (
  SELECT voter.voter_id, p.email
  FROM voter
  JOIN person p ON p.person_id = voter.voter_id
),
e AS (SELECT event_id, event_type FROM event),
ins AS (
  INSERT INTO event_attendance (event_id, voter_id, checked_in_at, attendance_type)
  SELECT (SELECT event_id FROM e WHERE event_type='rally'  LIMIT 1),
         (SELECT voter_id FROM vt WHERE email='alice@ex.org'),
         now(), 'in-person'
  UNION ALL
  SELECT (SELECT event_id FROM e WHERE event_type='town_hall' LIMIT 1),
         (SELECT voter_id FROM vt WHERE email='bob@ex.org'),
         now(), 'online'
  ON CONFLICT (event_id, voter_id) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH c AS (SELECT campaign_id FROM campaign WHERE name='City 2026 Mayoral'),
s AS (
  INSERT INTO survey (campaign_id, title, channel, start_date, end_date)
  SELECT (SELECT campaign_id FROM c), 'Springfield Issues', 'field'::channel_enum, DATE '2026-02-01', DATE '2026-03-01'
  ON CONFLICT (campaign_id, title) DO NOTHING
  RETURNING survey_id
),
sid AS (
  SELECT survey_id FROM s
  UNION ALL
  SELECT survey_id FROM survey WHERE title='Springfield Issues'
),
q AS (
  INSERT INTO survey_question (survey_id, question_text, question_type, position)
  SELECT survey_id, 'Top concern?', 'text', 1 FROM sid
  UNION ALL
  SELECT survey_id, 'Support candidate A?', 'single', 2 FROM sid
  UNION ALL
  SELECT survey_id, 'Rate city services (1-5)', 'scale', 3 FROM sid
  ON CONFLICT (survey_id, position) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM q);

WITH s AS (SELECT survey_id FROM survey WHERE title='Springfield Issues'),
q1 AS (SELECT question_id FROM survey_question WHERE position=1 AND survey_id IN (SELECT survey_id FROM s)),
q2 AS (SELECT question_id FROM survey_question WHERE position=2 AND survey_id IN (SELECT survey_id FROM s)),
vt AS (
  SELECT voter.voter_id, p.email
  FROM voter
  JOIN person p ON p.person_id = voter.voter_id
),
ins AS (
  INSERT INTO survey_response (survey_id, question_id, voter_id, answer_text, answer_code)
  SELECT (SELECT survey_id FROM s), (SELECT question_id FROM q1),
         (SELECT voter_id FROM vt WHERE email='alice@ex.org'),
         'transport', NULL
  UNION ALL
  SELECT (SELECT survey_id FROM s), (SELECT question_id FROM q2),
         (SELECT voter_id FROM vt WHERE email='alice@ex.org'),
         NULL, 'yes'
  UNION ALL
  SELECT (SELECT survey_id FROM s), (SELECT question_id FROM q2),
         (SELECT voter_id FROM vt WHERE email='bob@ex.org'),
         NULL, 'no'
  ON CONFLICT (survey_id, question_id, voter_id) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH c AS (SELECT campaign_id, name FROM campaign),
d AS (
  SELECT d.donor_id, p.email
  FROM donor d
  JOIN person p ON p.person_id = d.donor_id
),
e AS (SELECT event_id, event_type FROM event),
ins AS (
  INSERT INTO contribution
    (campaign_id, donor_id, event_id, contribution_date, amount, currency, method, purpose, receipt_no)
  SELECT (SELECT campaign_id FROM c WHERE name='City 2026 Mayoral'),
         (SELECT donor_id    FROM d WHERE email='carol@ex.org'),
         (SELECT event_id    FROM e WHERE event_type='rally' LIMIT 1),
         DATE '2026-02-01', 500.00, 'USD', 'card', 'general', 'R-0001'
  UNION ALL
  SELECT (SELECT campaign_id FROM c WHERE name='State 2026 Senate'),
         (SELECT donor_id    FROM d WHERE email='dan@ex.org'),
         NULL,
         DATE '2026-01-16', 1200.00,'USD','wire','ads','R-0002'
  ON CONFLICT (campaign_id, donor_id, contribution_date, amount, method) DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH c AS (SELECT campaign_id, name FROM campaign),
ins AS (
  INSERT INTO finance_expense
    (campaign_id, expense_date, amount, currency, category, vendor_name, memo)
  SELECT (SELECT campaign_id FROM c WHERE name='City 2026 Mayoral'),
         DATE '2026-02-02', 300.00, 'USD', 'ads', 'MediaCo', 'poster print'
  UNION ALL
  SELECT (SELECT campaign_id FROM c WHERE name='State 2026 Senate'),
         DATE '2026-01-20', 900.00, 'USD', 'travel', 'FlyFast', 'stump tour'
  ON CONFLICT DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH c AS (SELECT campaign_id, name FROM campaign),
ins AS (
  INSERT INTO problem_report (campaign_id, category, severity, description, status)
  SELECT (SELECT campaign_id FROM c WHERE name='City 2026 Mayoral'),
         'logistics','low','late banner delivery','open'
  UNION ALL
  SELECT (SELECT campaign_id FROM c WHERE name='State 2026 Senate'),
         'incident','high','minor crowd scuffle','resolved'
  ON CONFLICT DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

WITH e AS (SELECT event_id, event_type FROM event),
vt AS (
  SELECT voter.voter_id, p.email
  FROM voter
  JOIN person p ON p.person_id = voter.voter_id
),
ins AS (
  INSERT INTO social_interaction (event_id, voter_id, platform, occurred_at, interaction_type, sentiment, permalink)
  SELECT (SELECT event_id FROM e WHERE event_type='rally' LIMIT 1),
         (SELECT voter_id FROM vt WHERE email='alice@ex.org'),
         'twitter', now(), 'share', 'pos'::sentiment_enum, 'https://social/t/1'
  UNION ALL
  SELECT (SELECT event_id FROM e WHERE event_type='town_hall' LIMIT 1),
         (SELECT voter_id FROM vt WHERE email='bob@ex.org'),
         'facebook', now(), 'comment', 'neu'::sentiment_enum, 'https://social/f/2'
  ON CONFLICT DO NOTHING
  RETURNING 1
)
SELECT 1 WHERE EXISTS (SELECT 1 FROM ins);

DO $$
DECLARE
  t TEXT;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'campaign_app'
  LOOP
    EXECUTE format('ALTER TABLE campaign_app.%I ADD COLUMN IF NOT EXISTS record_ts DATE NOT NULL DEFAULT CURRENT_DATE;', t);
    EXECUTE format('UPDATE campaign_app.%I SET record_ts = CURRENT_DATE WHERE record_ts IS NULL;', t);
  END LOOP;
END$$;

COMMIT;
