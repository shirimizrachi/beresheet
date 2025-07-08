# Database Initialization Guide

This document provides instructions for initializing the database schemas and tables for the Home application.

## Prerequisites

1. **SQL Server Express** installed and running on `localhost\SQLEXPRESS`
2. **Home database** already created with login credentials:
   - Database: `home`
   - Username: `home`
   - Password: `home2025!`
3. **Python environment** with required packages:
   ```bash
   pip install sqlalchemy pyodbc
   ```

## Database Initialization Steps

### Step 1: Create Schema

Create a new schema in the home database:

```bash
# Navigate to deployment directory
cd deployment

# Create the beresheet schema
python create_schema.py beresheet
```

### Step 2: Create Users Table

Create the users table in the beresheet schema:

```bash
# Create users table in beresheet schema
python create_users_table.py beresheet
```

### Step 3: Create Events Table

Create the events table in the beresheet schema:

```bash
# Create events table in beresheet schema
python create_events_table.py beresheet
```

### Step 4: Create Events Registration Table

Create the events registration table in the beresheet schema:

```bash
# Create events registration table in beresheet schema
python create_events_registration_table.py beresheet
```

## Complete Initialization for Beresheet Schema

To set up everything for the beresheet schema in one go:

```bash
cd deployment
python create_schema.py beresheet
python create_users_table.py beresheet
python create_events_table.py beresheet
python create_events_registration_table.py beresheet
```

## Expected Output

After successful execution, you should see:
- Schema 'beresheet' created successfully
- Users table created successfully in schema 'beresheet' with indexes

## Database Structure

The initialized database will have:

### Schema: `beresheet`
### Table: `beresheet.users`

Columns:
- `id` (NVARCHAR(50), Primary Key)
- `firebase_id` (NVARCHAR(50), Unique, Not Null)
- `user_id` (NVARCHAR(50), Unique, Not Null)
- `home_id` (INT, Not Null)
- `display_name` (NVARCHAR(100))
- `full_name` (NVARCHAR(100))
- `email` (NVARCHAR(255))
- `phone_number` (NVARCHAR(20))
- `birth_date` (DATE)
- `birthday` (DATE)
- `gender` (NVARCHAR(10))
- `city` (NVARCHAR(50))
- `address` (NVARCHAR(255))
- `apartment_number` (NVARCHAR(50))
- `marital_status` (NVARCHAR(20))
- `religious` (NVARCHAR(50))
- `native_language` (NVARCHAR(50))
- `role` (NVARCHAR(50), Default: 'resident')
- `photo` (NVARCHAR(500))
- `created_at` (DATETIME2, Default: Current timestamp)
- `updated_at` (DATETIME2, Default: Current timestamp)

### Indexes Created:
- Index on `firebase_id`
- Index on `user_id`
- Index on `home_id`
- Index on `phone_number`
- Index on `role`

### Table: `beresheet.events`

Columns:
- `id` (NVARCHAR(50), Primary Key)
- `name` (NVARCHAR(100), Not Null)
- `type` (NVARCHAR(50), Not Null)
- `description` (NVARCHAR(MAX))
- `date_time` (DATETIME2, Not Null)
- `location` (NVARCHAR(200))
- `max_participants` (INT, Not Null, Default: 0)
- `current_participants` (INT, Not Null, Default: 0)
- `image_url` (NVARCHAR(500))
- `is_registered` (BIT, Default: 0)
- `created_at` (DATETIME2, Default: Current timestamp)
- `updated_at` (DATETIME2, Default: Current timestamp)
- `created_by` (NVARCHAR(50))
- `status` (NVARCHAR(20), Default: 'active')

### Indexes Created for Events:
- Index on `type`
- Index on `date_time` (for upcoming events queries)
- Index on `status`
- Index on `created_by`
- Composite index on `type` and `date_time`

### Table: `beresheet.events_registration`

Columns:
- `id` (NVARCHAR(50), Primary Key)
- `event_id` (NVARCHAR(50), Not Null)
- `user_id` (NVARCHAR(50), Not Null)
- `user_name` (NVARCHAR(100))
- `user_phone` (NVARCHAR(20))
- `registration_date` (DATETIME2, Default: Current timestamp)
- `status` (NVARCHAR(20), Default: 'registered') - "registered", "cancelled", "attended"
- `notes` (NVARCHAR(MAX))
- `created_at` (DATETIME2, Default: Current timestamp)
- `updated_at` (DATETIME2, Default: Current timestamp)

### Indexes Created for Events Registration:
- Index on `event_id` (for fast lookup of event registrations)
- Index on `user_id` (for fast lookup of user registrations)
- Index on `registration_date` (for chronological queries)
- Index on `status`
- Composite index on `event_id` and `registration_date`
- Unique constraint on `event_id` and `user_id` (prevents duplicate registrations)

## Adding Additional Schemas

To create additional schemas for other residents:

```bash
# Example for resident ID 2 (you would need to add this mapping to resident_mapping.py first)
python create_schema.py schema_name_for_resident_2
python create_users_table.py schema_name_for_resident_2
```

## Troubleshooting

### Common Issues:

1. **Connection Failed**: Ensure SQL Server Express is running and accessible
2. **Login Failed**: Verify the `home` user exists with correct password
3. **Schema Already Exists**: The script will inform you if schema already exists
4. **Table Already Exists**: The script will drop and recreate the table

### Verification

To verify the setup worked correctly:

1. Connect to SQL Server Management Studio
2. Navigate to `home` database
3. Check for `beresheet` schema under Schemas
4. Check for `users` table under `beresheet.Tables`
5. Verify indexes under the table's Indexes folder

## Resident ID Mapping

The application uses the following mapping (configured in `api_service/resident_mapping.py`):
- Resident ID `1` → Schema `beresheet`

Additional mappings can be added as needed.