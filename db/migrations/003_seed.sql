-- Seed ~250 bookings across 5 orgs, 6 cities, 4 statuses; events for ~40% of them.
-- Runs at container init via docker-entrypoint-initdb.d - fires once on a fresh
-- volume. To re-seed, `docker compose down -v && docker compose up -d`.
--
-- NOTE: bookings are intentionally skewed toward delhi + recent, so the aggregation
-- query has non-trivial data. If you want an even distribution for perf tests, drop
-- the CASE below.

DO $$
DECLARE
    cities   TEXT[] := ARRAY['delhi','mumbai','bangalore','hyderabad','goa','jaipur'];
    statuses TEXT[] := ARRAY['confirmed','cancelled','pending','completed'];
    org_ids  UUID[] := ARRAY[
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid(), gen_random_uuid()
    ];
    booking_ids UUID[] := ARRAY[]::UUID[];
    b UUID;
BEGIN
    -- Skew a good chunk of bookings toward delhi + last 30 days so the
    -- aggregation query has non-trivial data to chew on.
    FOR i IN 1..250 LOOP
        b := gen_random_uuid();
        booking_ids := array_append(booking_ids, b);

        INSERT INTO hotel_bookings (
            id, org_id, hotel_id, city, checkin_date, checkout_date,
            amount, status, created_at
        ) VALUES (
            b,
            org_ids[1 + (i % array_length(org_ids, 1))],
            'HTL-' || lpad(((i * 37) % 400)::text, 4, '0'),
            CASE
                WHEN i % 3 = 0 THEN 'delhi'
                ELSE cities[1 + (i % array_length(cities, 1))]
            END,
            CURRENT_DATE - ((random() * 60)::int),
            CURRENT_DATE - ((random() * 60)::int) + ((1 + random() * 5)::int),
            round((1500 + random() * 18500)::numeric, 2),
            statuses[1 + (i % array_length(statuses, 1))],
            NOW() - (random() * INTERVAL '45 days')
        );
    END LOOP;

    -- Events for ~40% of bookings, 1-3 each.
    FOREACH b IN ARRAY booking_ids LOOP
        CONTINUE WHEN random() > 0.4;

        FOR j IN 1..(1 + (random() * 2)::int) LOOP
            INSERT INTO booking_events (booking_id, event_type, payload, created_at)
            VALUES (
                b,
                (ARRAY['created','payment_captured','confirmed','cancelled','refunded'])[1 + (j % 5)],
                jsonb_build_object(
                    'source', (ARRAY['web','ios','android','partner_api'])[1 + (j % 4)],
                    'attempt', j
                ),
                NOW() - (random() * INTERVAL '30 days')
            );
        END LOOP;
    END LOOP;
END $$;

ANALYZE hotel_bookings;
ANALYZE booking_events;
