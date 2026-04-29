import re
import random
from .models import Book, Chapter

class AIModerationService:
    # Basic keyword-based toxicity detection (Stage 1)
    # In a production environment, this should call Google Perspective API or similar.
    TOXIC_KEYWORDS = [
        r'hate', r'kill', r'die', r'stupid', r'idiot', r'fuck', r'shit', r'bitch', 
        r'asshole', r'violence', r'weapon', r'abuse', r'sexual', r'porn'
    ]

    @staticmethod
    def evaluate_text_toxicity(text):
        if not text:
            return 0.0, []
        
        matches = []
        score = 0.0
        
        for pattern in AIModerationService.TOXIC_KEYWORDS:
            if re.search(pattern, text, re.IGNORECASE):
                matches.append(pattern)
                score += 0.15 # Incremental score per violation type
        
        # Cap the score at 1.0
        return min(score, 1.0), list(set(matches))

    @staticmethod
    def check_plagiarism_locally(text, book_id):
        """
        Check for high similarity against other books in the database.
        (Stage 1 Plagiarism Detection)
        """
        if not text or len(text) < 100:
            return 0.0
        
        # Simplified: Check for identical long strings in other chapters
        # In production, use vector embeddings (e.g. Pinecone/Chroma)
        snippet = text[:200]
        duplicate_exists = Chapter.objects.exclude(book_id=book_id).filter(content__icontains=snippet).exists()
        
        return 0.85 if duplicate_exists else 0.0

    @classmethod
    def evaluate_book(cls, book_id):
        try:
            book = Book.objects.get(id=book_id)
            book.ai_evaluation_status = 'processing'
            book.save()

            all_chapters = book.chapters.all()
            full_content = " ".join([c.content for c in all_chapters if c.content])
            full_text = f"{book.title} {book.description} {full_content}"

            # 1. Toxicity Check
            toxicity_score, flags = cls.evaluate_text_toxicity(full_text)
            
            # 2. Plagiarism Check
            # Using a mock score for now, or the local check
            plagiarism_score = cls.check_plagiarism_locally(full_text, book_id)

            # Update book record
            book.ai_moderation_score = toxicity_score
            book.plagiarism_score = plagiarism_score
            book.ai_flagged = toxicity_score > 0.4 or plagiarism_score > 0.5
            
            reasons = []
            if toxicity_score > 0.4:
                reasons.append(f"High toxicity detected: {', '.join(flags)}")
            if plagiarism_score > 0.5:
                reasons.append("High similarity found with existing content.")
            
            book.ai_flag_reason = " | ".join(reasons) if reasons else ""
            book.ai_evaluation_status = 'completed'
            book.save()

            return {
                'success': True,
                'flagged': book.ai_flagged,
                'score': toxicity_score,
                'plagiarism': plagiarism_score,
                'reason': book.ai_flag_reason
            }

        except Book.DoesNotExist:
            return {'success': False, 'error': 'Book not found'}
        except Exception as e:
            return {'success': False, 'error': str(e)}
