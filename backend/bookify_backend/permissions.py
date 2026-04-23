from rest_framework import permissions

class IsAdminUser(permissions.BasePermission):
    """
    Custom permission to only allow platform admins to access a view.
    """
    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        
        # Check the role field in the Profile model
        return hasattr(request.user, 'profile') and request.user.profile.role == 'admin'
