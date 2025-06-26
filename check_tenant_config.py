import sys
sys.path.append('api_service')

try:
    from api_service.tenant_config import get_all_homes, get_schema_name_by_home_id
    print('Available homes:')
    homes = get_all_homes()
    for home in homes:
        print(f'  ID: {home["id"]}, Name: {home["name"]}, Schema: {home["schema"]}')
    
    print(f'\nSchema for home_id 53: {get_schema_name_by_home_id(53)}')
    print(f'Schema for home_id 1: {get_schema_name_by_home_id(1)}')
    
    # Also check the demo data
    print('\nChecking demo data:')
    import csv
    csv_file = 'api_service/deployment/schema/demo/data/users.csv'
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        users = list(reader)
        print(f'Demo users found: {len(users)}')
        for user in users[:3]:  # Show first 3 users
            print(f'  Phone: {user["phone_number"]}, Name: {user["full_name"]}, Home ID: {user["home_id"]}')
        if len(users) > 3:
            print(f'  ... and {len(users) - 3} more users')
            
except Exception as e:
    print(f'Error: {e}')
    import traceback
    traceback.print_exc()