"""
Requests management using SQLAlchemy
Provides CRUD operations for communication between residents and service providers.
"""

import json
import uuid
from typing import List, Optional
from datetime import datetime

from sqlalchemy import create_engine, MetaData, Table, text
from models import Request, RequestCreate, RequestUpdate, RequestStatusUpdate, ChatMessage
from home_mapping import get_connection_string, get_schema_for_home
from database_utils import get_schema_engine, get_engine_for_home
from users import user_db


class RequestDatabase:
    """
    Handles all request-related database operations for communication
    between residents and service providers.
    """

    def __init__(self):
        # Generic connection string (server-level); most ops will use schema-specific engines
        self.connection_string = get_connection_string()
        self.engine = create_engine(self.connection_string)

    # --------------------------------------------------------------------- #
    # Table reflection helper                                               #
    # --------------------------------------------------------------------- #
    def _get_requests_table(self, schema_name: str) -> Optional[Table]:
        """
        Reflect the **requests** table from the specified schema and return it.
        """
        try:
            schema_engine = get_schema_engine(schema_name)
            if not schema_engine:
                print(f"No engine found for schema {schema_name}")
                return None

            metadata = MetaData(schema=schema_name)
            metadata.reflect(bind=schema_engine, only=["requests"])
            return metadata.tables[f"{schema_name}.requests"]
        except Exception as exc:
            print(f"Error reflecting requests table for schema {schema_name}: {exc}")
            return None

    # --------------------------------------------------------------------- #
    # Helper methods for user information                                   #
    # --------------------------------------------------------------------- #
    def _get_user_info(self, user_id: str, home_id: int) -> dict:
        """Get user information for populating request fields"""
        user = user_db.get_user_profile(user_id, home_id)
        if user:
            return {
                'full_name': user.full_name,
                'phone_number': user.phone_number,
                'fcm_token': user.firebase_fcm_token,
                'service_provider_type': user.service_provider_type,
                'service_provider_type_id': user.service_provider_type_id
            }
        return {
            'full_name': None,
            'phone_number': None,
            'fcm_token': None,
            'service_provider_type': None
        }
    
    def _get_service_provider_type_details(self, service_provider_type_id: int, home_id: int) -> dict:
        """Get service provider type name and description by ID"""
        try:
            from service_provider_types import service_provider_type_db
            service_type = service_provider_type_db.get_service_provider_type_by_id(service_provider_type_id, home_id)
            if service_type:
                return {
                    'name': service_type.name,
                    'description': service_type.description
                }
            return {
                'name': None,
                'description': None
            }
        except Exception as e:
            print(f"Error getting service provider type details: {e}")
            return {
                'name': None,
                'description': None
            }

    def _calculate_duration(self, created_at: datetime, closed_at: Optional[datetime]) -> Optional[int]:
        """Calculate request duration in minutes"""
        if closed_at and created_at:
            delta = closed_at - created_at
            return int(delta.total_seconds() / 60)
        return None

    # --------------------------------------------------------------------- #
    # CRUD operations                                                       #
    # --------------------------------------------------------------------- #
    def create_request(self, request_data: RequestCreate, resident_id: str, home_id: int) -> Optional[Request]:
        """Create a new request from resident to service provider"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return None

            # Get user information
            resident_info = self._get_user_info(resident_id, home_id)
            service_provider_info = self._get_user_info(request_data.service_provider_id, home_id)
            
            # Get service provider type details
            service_provider_type_id = service_provider_info['service_provider_type_id']
            service_provider_type_details = self._get_service_provider_type_details(service_provider_type_id, home_id) if service_provider_type_id else {'name': None, 'description': None}
            
            print(f"DEBUG: service_provider_type_id: {service_provider_type_id}")
            print(f"DEBUG: service_provider_type_details: {service_provider_type_details}")

            # Generate unique request ID
            request_id = str(uuid.uuid4())

            with self.engine.connect() as conn:
                insert_result = conn.execute(
                    requests_table.insert().values(
                        id=request_id,
                        resident_id=resident_id,
                        resident_phone_number=resident_info['phone_number'],
                        resident_full_name=resident_info['full_name'],
                        resident_fcm_token=resident_info['fcm_token'],
                        service_provider_id=request_data.service_provider_id,
                        service_provider_full_name=service_provider_info['full_name'],
                        service_provider_phone_number=service_provider_info['phone_number'],
                        service_provider_fcm_token=service_provider_info['fcm_token'],
                        service_provider_type_name=service_provider_type_details['name'],
                        service_provider_type_description=service_provider_type_details['description'],
                        request_message=request_data.request_message,
                        request_status='open'
                    )
                )
                conn.commit()

                # Fetch the newly created request
                new_row = conn.execute(
                    requests_table.select().where(requests_table.c.id == request_id)
                ).fetchone()

                if new_row:
                    return self._row_to_request(new_row)
                return None
        except Exception as exc:
            print(f"Error creating request for resident {resident_id} and service provider {request_data.service_provider_id}: {exc}")
            return None

    def get_request_by_id(self, request_id: str, home_id: int) -> Optional[Request]:
        """Get a specific request by ID"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return None

            with self.engine.connect() as conn:
                result = conn.execute(
                    requests_table.select().where(requests_table.c.id == request_id)
                ).fetchone()

                if result:
                    return self._row_to_request(result)
                return None
        except Exception as exc:
            print(f"Error retrieving request {request_id}: {exc}")
            return None

    def get_requests_by_resident(self, resident_id: str, home_id: int, status_filter: Optional[str] = None) -> List[Request]:
        """Get all requests created by a specific resident with service provider details"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            schema_engine = get_schema_engine(schema_name)
            with schema_engine.connect() as conn:
                # Enhanced query with service provider information
                query_sql = text(f"""
                    SELECT r.*,
                           u.full_name as service_provider_full_name,
                           u.photo as service_provider_photo,
                           spt.name as service_provider_type_name,
                           spt.description as service_provider_type_description
                    FROM [{schema_name}].[requests] r
                    LEFT JOIN [{schema_name}].[users] u ON r.service_provider_id = u.id
                    LEFT JOIN [{schema_name}].[service_provider_types] spt ON u.service_provider_type_id = spt.id
                    WHERE r.resident_id = :resident_id
                    {f"AND r.request_status = :status" if status_filter else ""}
                    ORDER BY r.request_created_at DESC
                """)
                
                params = {'resident_id': resident_id}
                if status_filter:
                    params['status'] = status_filter
                
                results = conn.execute(query_sql, params).fetchall()
                
                # Convert results to Request objects with additional fields
                requests = []
                for row in results:
                    request_dict = dict(row._mapping)
                    # Add service provider details to the request
                    request_dict['service_provider_full_name'] = request_dict.get('service_provider_full_name')
                    request_dict['service_provider_photo'] = request_dict.get('service_provider_photo')
                    request_dict['service_provider_type_name'] = request_dict.get('service_provider_type_name')
                    request_dict['service_provider_type_description'] = request_dict.get('service_provider_type_description')
                    
                    request = self._row_to_request(type('Row', (), request_dict)())
                    requests.append(request)
                
                return requests
        except Exception as exc:
            print(f"Error retrieving requests for resident {resident_id}: {exc}")
            return []

    def get_requests_by_service_provider(self, service_provider_id: str, home_id: int, status_filter: Optional[str] = None) -> List[Request]:
        """Get all requests assigned to a specific service provider"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return []

            with self.engine.connect() as conn:
                query = requests_table.select().where(requests_table.c.service_provider_id == service_provider_id)
                
                if status_filter:
                    query = query.where(requests_table.c.request_status == status_filter)
                
                query = query.order_by(requests_table.c.request_created_at.desc())
                
                results = conn.execute(query).fetchall()
                return [self._row_to_request(row) for row in results]
        except Exception as exc:
            print(f"Error retrieving requests for service provider {service_provider_id}: {exc}")
            return []

    def get_requests_by_service_provider_type(self, service_provider_type: str, home_id: int, status_filter: Optional[str] = None) -> List[Request]:
        """Get all requests for a specific service provider type"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return []

            with self.engine.connect() as conn:
                query = requests_table.select().where(requests_table.c.service_provider_type == service_provider_type)
                
                if status_filter:
                    query = query.where(requests_table.c.request_status == status_filter)
                
                query = query.order_by(requests_table.c.request_created_at.desc())
                
                results = conn.execute(query).fetchall()
                return [self._row_to_request(row) for row in results]
        except Exception as exc:
            print(f"Error retrieving requests for service provider type {service_provider_type}: {exc}")
            return []

    def get_all_requests(self, home_id: int, status_filter: Optional[str] = None) -> List[Request]:
        """Get all requests (admin view)"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return []

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return []

            with self.engine.connect() as conn:
                query = requests_table.select()
                
                if status_filter:
                    query = query.where(requests_table.c.request_status == status_filter)
                
                query = query.order_by(requests_table.c.request_created_at.desc())
                
                results = conn.execute(query).fetchall()
                return [self._row_to_request(row) for row in results]
        except Exception as exc:
            print(f"Error retrieving all requests for home {home_id}: {exc}")
            return []

    def update_request(self, request_id: str, request_data: RequestUpdate, home_id: int) -> Optional[Request]:
        """Update a request"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return None

            with self.engine.connect() as conn:
                # Build update dictionary
                update_data = {}
                
                if request_data.request_message is not None:
                    update_data['request_message'] = request_data.request_message
                
                if request_data.request_status is not None:
                    update_data['request_status'] = request_data.request_status
                
                if request_data.service_rating is not None:
                    update_data['service_rating'] = request_data.service_rating
                
                if request_data.service_comment is not None:
                    update_data['service_comment'] = request_data.service_comment
                
                if request_data.chat_messages is not None:
                    update_data['chat_messages'] = request_data.chat_messages

                if not update_data:
                    # No data to update, return existing request
                    return self.get_request_by_id(request_id, home_id)

                result = conn.execute(
                    requests_table.update()
                    .where(requests_table.c.id == request_id)
                    .values(**update_data)
                )
                conn.commit()

                if result.rowcount > 0:
                    return self.get_request_by_id(request_id, home_id)
                return None
        except Exception as exc:
            print(f"Error updating request {request_id}: {exc}")
            return None

    def update_request_status(self, request_id: str, status_update: RequestStatusUpdate, home_id: int) -> Optional[Request]:
        """Update request status with timestamps"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return None

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return None

            with self.engine.connect() as conn:
                update_data = {'request_status': status_update.request_status}
                
                current_time = datetime.now()
                
                if status_update.mark_as_read:
                    update_data['request_read_at'] = current_time
                
                if status_update.close_by_resident:
                    update_data['request_closed_by_resident_at'] = current_time
                
                if status_update.close_by_service_provider:
                    update_data['request_closed_by_service_provider_at'] = current_time
                
                # Calculate duration if request is being closed
                if status_update.request_status == 'closed':
                    existing_request = self.get_request_by_id(request_id, home_id)
                    if existing_request:
                        duration = self._calculate_duration(existing_request.request_created_at, current_time)
                        if duration:
                            update_data['request_duration_minutes'] = duration

                result = conn.execute(
                    requests_table.update()
                    .where(requests_table.c.id == request_id)
                    .values(**update_data)
                )
                conn.commit()

                if result.rowcount > 0:
                    return self.get_request_by_id(request_id, home_id)
                return None
        except Exception as exc:
            print(f"Error updating request status {request_id}: {exc}")
            return None

    def add_chat_message(self, request_id: str, sender_id: str, sender_type: str, message: str, home_id: int) -> Optional[Request]:
        """Add a chat message to a request"""
        try:
            existing_request = self.get_request_by_id(request_id, home_id)
            if not existing_request:
                return None

            # Parse existing chat messages
            chat_messages = []
            if existing_request.chat_messages:
                try:
                    chat_messages = json.loads(existing_request.chat_messages)
                except json.JSONDecodeError:
                    chat_messages = []

            # Add new message
            new_message = {
                'message_id': str(uuid.uuid4()),
                'sender_id': sender_id,
                'sender_type': sender_type,
                'message': message,
                'timestamp': datetime.now().isoformat()
            }
            chat_messages.append(new_message)

            # Update request with new chat messages
            update_data = RequestUpdate(chat_messages=json.dumps(chat_messages))
            return self.update_request(request_id, update_data, home_id)

        except Exception as exc:
            print(f"Error adding chat message to request {request_id}: {exc}")
            return None

    def get_chat_messages(self, request_id: str, home_id: int) -> List[dict]:
        """Get all chat messages for a request"""
        try:
            existing_request = self.get_request_by_id(request_id, home_id)
            if not existing_request:
                return []

            # Parse existing chat messages
            if existing_request.chat_messages:
                try:
                    chat_messages = json.loads(existing_request.chat_messages)
                    return chat_messages if isinstance(chat_messages, list) else []
                except json.JSONDecodeError:
                    return []
            return []
        except Exception as exc:
            print(f"Error getting chat messages for request {request_id}: {exc}")
            return []

    def update_chat_messages(self, request_id: str, chat_messages: List[dict], home_id: int) -> Optional[Request]:
        """Update the entire chat messages array for a request"""
        try:
            # Validate that each message has required fields
            for message in chat_messages:
                if not isinstance(message, dict) or 'message' not in message or 'created_time' not in message:
                    raise ValueError("Each chat message must have 'message' and 'created_time' fields")

            # Update request with new chat messages
            update_data = RequestUpdate(chat_messages=json.dumps(chat_messages))
            return self.update_request(request_id, update_data, home_id)

        except Exception as exc:
            print(f"Error updating chat messages for request {request_id}: {exc}")
            return None

    def delete_request(self, request_id: str, home_id: int) -> bool:
        """Delete a request (admin only)"""
        try:
            schema_name = get_schema_for_home(home_id)
            if not schema_name:
                return False

            requests_table = self._get_requests_table(schema_name)
            if requests_table is None:
                return False

            with self.engine.connect() as conn:
                result = conn.execute(
                    requests_table.delete().where(requests_table.c.id == request_id)
                )
                conn.commit()
                return result.rowcount > 0
        except Exception as exc:
            print(f"Error deleting request {request_id}: {exc}")
            return False

    # --------------------------------------------------------------------- #
    # Helper methods                                                        #
    # --------------------------------------------------------------------- #
    def _row_to_request(self, row) -> Request:
        """Convert database row to Request model"""
        return Request(
            id=row.id,
            resident_id=row.resident_id,
            resident_phone_number=row.resident_phone_number,
            resident_full_name=row.resident_full_name,
            resident_fcm_token=row.resident_fcm_token,
            service_provider_id=row.service_provider_id,
            service_provider_full_name=row.service_provider_full_name,
            service_provider_phone_number=row.service_provider_phone_number,
            service_provider_fcm_token=row.service_provider_fcm_token,
            service_provider_photo=getattr(row, 'service_provider_photo', None),
            service_provider_type_name=getattr(row, 'service_provider_type_name', None),
            service_provider_type_description=getattr(row, 'service_provider_type_description', None),
            request_message=row.request_message,
            request_status=row.request_status,
            request_created_at=row.request_created_at,
            request_modified_at=getattr(row, 'request_modified_at', None),
            request_read_at=row.request_read_at,
            request_closed_by_resident_at=row.request_closed_by_resident_at,
            request_closed_by_service_provider_at=row.request_closed_by_service_provider_at,
            chat_messages=row.chat_messages,
            service_rating=row.service_rating,
            service_comment=row.service_comment,
            request_duration_minutes=row.request_duration_minutes,
            created_at=row.created_at,
            updated_at=row.updated_at
        )


# Global singleton instance
request_db = RequestDatabase()