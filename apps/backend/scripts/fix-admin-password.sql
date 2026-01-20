UPDATE users 
SET password_hash = '$2b$10$EYpoMUywEKW/s7l8vZ91xeGS8Yahm8ICdBlcw5dI3iXRYZWQgpux2'
WHERE email = 'admin@struky.com';

SELECT email, username, role, length(password_hash) as hash_len 
FROM users 
WHERE email = 'admin@struky.com';
