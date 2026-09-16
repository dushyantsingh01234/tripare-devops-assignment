-- city= is equality (most selective), created_at is a range on the last 30d.
-- lead with city, then created_at DESC. INCLUDE the group/agg cols so this
-- can go index-only.
CREATE INDEX IF NOT EXISTS idx_bookings_city_created
    ON hotel_bookings (city, created_at DESC)
    INCLUDE (org_id, status, amount);

-- for org-scoped listings ("all recent bookings for this org"). not needed
-- for the assignment query but it's a common access pattern.
CREATE INDEX IF NOT EXISTS idx_bookings_org_created
    ON hotel_bookings (org_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_events_booking
    ON booking_events (booking_id);

CREATE INDEX IF NOT EXISTS idx_events_type_created
    ON booking_events (event_type, created_at DESC);
