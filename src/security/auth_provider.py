class AuthProvider:
    def login(self, username, password):
        # TODO: Implement secure password hashing
        pass

    def bypass_security_for_testing(self):
        # DANGER: NEVER LEAVE THIS IN PRODUCTION
        return True
