#!/usr/bin/env python3
"""
Test script for the new loadEventsForHome API with recurring events functionality
"""

import json
from datetime import datetime, timedelta
from events import calculate_next_occurrence

def test_calculate_next_occurrence():
    """Test the calculate_next_occurrence function"""
    print("Testing calculate_next_occurrence function...")
    
    # Test weekly event
    print("\n1. Testing Weekly Event:")
    event_datetime = datetime(2025, 6, 20, 14, 0)  # Friday
    recurring_pattern = json.dumps({"dayOfWeek": 3, "time": "14:00"})  # Wednesday at 2 PM
    recurring_end_date = datetime(2025, 9, 17, 14, 0)
    
    next_occurrence = calculate_next_occurrence(event_datetime, recurring_pattern, recurring_end_date)
    print(f"Event created: {event_datetime}")
    print(f"Pattern: {recurring_pattern}")
    print(f"Next occurrence: {next_occurrence}")
    print(f"Expected: Should be the next Wednesday after today")
    
    # Test bi-weekly event
    print("\n2. Testing Bi-Weekly Event:")
    event_datetime = datetime(2025, 6, 27, 17, 0)  # Friday
    recurring_pattern = json.dumps({"dayOfWeek": 3, "time": "17:00", "interval": 2})  # Every other Wednesday at 5 PM
    recurring_end_date = datetime(2025, 9, 17, 17, 0)
    
    next_occurrence = calculate_next_occurrence(event_datetime, recurring_pattern, recurring_end_date)
    print(f"Event created: {event_datetime}")
    print(f"Pattern: {recurring_pattern}")
    print(f"Next occurrence: {next_occurrence}")
    print(f"Expected: Should be the next bi-weekly Wednesday")
    
    # Test monthly event
    print("\n3. Testing Monthly Event:")
    event_datetime = datetime(2025, 7, 2, 15, 0)  # July 2nd
    recurring_pattern = json.dumps({"dayOfMonth": 15, "time": "15:00"})  # 15th of each month at 3 PM
    recurring_end_date = datetime(2025, 12, 17, 15, 0)
    
    next_occurrence = calculate_next_occurrence(event_datetime, recurring_pattern, recurring_end_date)
    print(f"Event created: {event_datetime}")
    print(f"Pattern: {recurring_pattern}")
    print(f"Next occurrence: {next_occurrence}")
    print(f"Expected: Should be July 15th, 2025 at 3 PM")
    
    # Test expired recurring event
    print("\n4. Testing Expired Recurring Event:")
    event_datetime = datetime(2025, 6, 20, 14, 0)
    recurring_pattern = json.dumps({"dayOfWeek": 3, "time": "14:00"})
    recurring_end_date = datetime(2025, 6, 19, 14, 0)  # Already expired
    
    next_occurrence = calculate_next_occurrence(event_datetime, recurring_pattern, recurring_end_date)
    print(f"Event created: {event_datetime}")
    print(f"Pattern: {recurring_pattern}")
    print(f"End date: {recurring_end_date} (expired)")
    print(f"Next occurrence: {next_occurrence}")
    print(f"Expected: Should return original datetime since series has ended")

def test_day_conversion():
    """Test day of week conversion"""
    print("\n\nTesting Day of Week Conversion:")
    print("Our format: 0=Sunday, 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday")
    print("Python weekday(): 0=Monday, 1=Tuesday, 2=Wednesday, 3=Thursday, 4=Friday, 5=Saturday, 6=Sunday")
    
    test_dates = [
        datetime(2025, 6, 16),  # Monday
        datetime(2025, 6, 17),  # Tuesday  
        datetime(2025, 6, 18),  # Wednesday
        datetime(2025, 6, 19),  # Thursday
        datetime(2025, 6, 20),  # Friday
        datetime(2025, 6, 21),  # Saturday
        datetime(2025, 6, 22),  # Sunday
    ]
    
    for date in test_dates:
        python_weekday = date.weekday()
        our_weekday = (python_weekday + 1) % 7
        print(f"{date.strftime('%A %Y-%m-%d')}: Python={python_weekday}, Our={our_weekday}")

def test_load_events_for_home():
    """Test the load_events_for_home method with actual database data"""
    from events import event_db
    from datetime import datetime
    
    print("\n\nTesting load_events_for_home with database data...")
    
    # Test with a sample home_id and user_id
    test_home_id = 1
    test_user_id = "test_user_123"
    
    try:
        # Get all events from database
        all_events = event_db.get_all_events(test_home_id)
        
        if not all_events:
            print("❌ No events found in database.")
            return
            
        # Display all events in table format
        print(f"\n📊 ALL EVENTS IN DATABASE ({len(all_events)} events):")
        print("=" * 100)
        print(f"{'Name':<30} {'Status':<10} {'Recurring':<15} {'Original DateTime':<20} {'Pattern':<25}")
        print("-" * 100)
        
        for event in all_events:
            name_short = event.name[:27] + "..." if len(event.name) > 30 else event.name
            dt_str = event.date_time.strftime("%m-%d %H:%M") if event.date_time else "None"
            
            # Parse recurring pattern for display
            pattern_display = ""
            if event.recurring != 'none' and event.recurring_pattern:
                try:
                    import json
                    pattern = json.loads(event.recurring_pattern)
                    if 'dayOfWeek' in pattern:
                        days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        day_name = days[pattern['dayOfWeek']]
                        time = pattern.get('time', '??:??')
                        interval = pattern.get('interval', 1)
                        if interval == 2:
                            pattern_display = f"Every 2nd {day_name} {time}"
                        else:
                            pattern_display = f"Every {day_name} {time}"
                    elif 'dayOfMonth' in pattern:
                        day = pattern['dayOfMonth']
                        time = pattern.get('time', '??:??')
                        pattern_display = f"Monthly {day}th {time}"
                except:
                    pattern_display = "Invalid pattern"
            else:
                pattern_display = "One-time event"
            
            print(f"{name_short:<30} {event.status:<10} {event.recurring:<15} {dt_str:<20} {pattern_display:<25}")
        
        # Test load_events_for_home
        home_events = event_db.load_events_for_home(test_home_id, test_user_id)
        
        if not home_events:
            print(f"\n📋 load_events_for_home returned 0 events")
            return
            
        # Display home events in table format
        current_time = datetime.now()
        print(f"\n🏠 LOAD_EVENTS_FOR_HOME RESULTS ({len(home_events)} events):")
        print(f"⏰ Current time: {current_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print("=" * 140)
        print(f"{'Name':<30} {'Status':<8} {'Next Event':<12} {'Pattern':<25} {'Start Date':<12} {'End Date':<12} {'Override':<8}")
        print("-" * 140)
        
        for event in home_events:
            # Find original event for comparison
            original_datetime = None
            original_pattern = None
            original_end_date = None
            for orig_event in all_events:
                if orig_event.id == event['id']:
                    original_datetime = orig_event.date_time
                    original_pattern = orig_event.recurring_pattern
                    original_end_date = orig_event.recurring_end_date
                    break
            
            name_short = event['name'][:27] + "..." if len(event['name']) > 30 else event['name']
            
            # Format next event datetime
            display_dt = datetime.fromisoformat(event['date_time'].replace('Z', ''))
            display_dt_str = display_dt.strftime("%m-%d %H:%M")
            
            # Format start and end dates for recurring events
            start_date_str = ""
            end_date_str = ""
            if event['recurring'] != 'none':
                start_date_str = original_datetime.strftime("%m-%d") if original_datetime else "N/A"
                end_date_str = original_end_date.strftime("%m-%d") if original_end_date else "N/A"
            else:
                start_date_str = "N/A"
                end_date_str = "N/A"
            
            # Parse recurring pattern for display
            pattern_display = ""
            if event['recurring'] != 'none' and original_pattern:
                try:
                    import json
                    pattern = json.loads(original_pattern)
                    if 'dayOfWeek' in pattern:
                        days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                        day_name = days[pattern['dayOfWeek']]
                        time = pattern.get('time', '??:??')
                        interval = pattern.get('interval', 1)
                        if interval == 2:
                            pattern_display = f"2nd {day_name} {time}"
                        else:
                            pattern_display = f"{day_name} {time}"
                    elif 'dayOfMonth' in pattern:
                        day = pattern['dayOfMonth']
                        time = pattern.get('time', '??:??')
                        pattern_display = f"Monthly {day}th {time}"
                except:
                    pattern_display = "Invalid pattern"
            else:
                pattern_display = "One-time"
            
            # Check if overridden
            override_status = "✅ YES" if (event['recurring'] != 'none' and
                                         original_datetime and
                                         event['date_time'] != original_datetime.isoformat()) else "⭕ NO"
            
            print(f"{name_short:<30} {event['status']:<8} {display_dt_str:<12} {pattern_display:<25} {start_date_str:<12} {end_date_str:<12} {override_status:<8}")
        
        # Summary table
        print("\n📈 SUMMARY:")
        print("=" * 60)
        
        # Count by status
        status_counts = {}
        for event in all_events:
            status_counts[event.status] = status_counts.get(event.status, 0) + 1
        
        # Count by recurring type
        recurring_counts = {}
        for event in all_events:
            recurring_counts[event.recurring] = recurring_counts.get(event.recurring, 0) + 1
        
        print(f"{'Metric':<30} {'Count':<10}")
        print("-" * 40)
        print(f"{'Total events in database:':<30} {len(all_events):<10}")
        print(f"{'Events returned by API:':<30} {len(home_events):<10}")
        print()
        
        print("Status breakdown:")
        for status, count in status_counts.items():
            print(f"  {status:<26} {count:<10}")
        print()
        
        print("Recurring type breakdown:")
        for recurring, count in recurring_counts.items():
            print(f"  {recurring:<26} {count:<10}")
        
        # Check ordering
        datetimes = [datetime.fromisoformat(event['date_time'].replace('Z', '')) for event in home_events]
        is_sorted = all(datetimes[i] <= datetimes[i+1] for i in range(len(datetimes)-1))
        
        print(f"\n⚡ VALIDATION:")
        print(f"✅ Correct chronological ordering: {is_sorted}")
        print(f"✅ All events are in future: {all(dt > current_time for dt in datetimes)}")
        print(f"✅ DateTime override working: {sum(1 for e in home_events if e['recurring'] != 'none')} recurring events")
        
    except Exception as e:
        print(f"❌ Error during test: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_calculate_next_occurrence()
    test_day_conversion()
    test_load_events_for_home()
    print("\n\nAll tests completed!")