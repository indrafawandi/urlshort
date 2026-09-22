from app.crud import generate_code


def test_generate_code_has_requested_length():
    assert len(generate_code(10)) == 10


def test_generate_code_is_alphanumeric():
    code = generate_code(20)
    assert code.isalnum()


def test_generate_code_is_reasonably_random():
    codes = {generate_code(8) for _ in range(200)}
    # With an 8-char alphanumeric code space, 200 draws colliding would
    # indicate a broken RNG, not bad luck.
    assert len(codes) == 200
