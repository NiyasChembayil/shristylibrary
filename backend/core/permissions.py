from rest_framework import permissions

class IsOwnerOrReadOnly(permissions.BasePermission):
    """
    Object-level permission to only allow owners of an object to edit or delete it.
    Assumes the model instance has a `user` or `author` attribute.
    """

    def has_object_permission(self, request, view, obj):
        # Read permissions are allowed to any request,
        # so we'll always allow GET, HEAD or OPTIONS requests.
        if request.method in permissions.SAFE_METHODS:
            return True

        # Instance must have an attribute named `user` or `author`.
        owner = getattr(obj, 'user', None) or getattr(obj, 'author', None)
        
        # If it's a chapter, check the book's author
        if not owner and hasattr(obj, 'book'):
            owner = obj.book.author
            
        return owner == request.user
