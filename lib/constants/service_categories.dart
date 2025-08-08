// A central place to manage all the service categories and skills offered in the app.
// This makes it easy to add, remove, or edit services without changing the UI code.

class AppServices {
  static const Map<String, List<String>> categories = {
    'Home & Garden': [
      'Plumbing',
      'Electrician',
      'Carpentry',
      'Painting',
      'Masonry & Tiling',
      'Gardening & Landscaping',
      'Pest Control',
      'Appliance Repair (AC, Fridge, etc.)',
      'Rooﬁng Repairs',
      'Welding Services',
    ],
    'Cleaning Services': [
      'General House Cleaning',
      'Office Cleaning',
      'Deep Cleaning',
      'Window Cleaning',
      'Sofa & Carpet Cleaning',
      'Post-Construction Cleaning',
    ],
    'Moving & Delivery': [
      'Movers & Packers',
      'Pickup & Delivery',
      'Furniture Assembly',
      'Junk Removal',
      'Heavy Lifting',
    ],
    'Events & Errands': [
      'Event Helper / Staff',
      'Errand Runner',
      'Personal Shopper',
      'Catering Assistance',
      'Flyer Distribution',
    ],
    'Automotive Services': [
      'Car Wash & Detailing',
      'Minor Vehicle Repairs',
      'Driver / Chauffeur',
      'Tire Change Assistance',
      'Battery Jump Start',
    ],
    'Digital & Creative': [
      'Graphic Design',
      'Content Writing & Translation',
      'Social Media Management',
      'Photography',
      'Videography',
      'Basic Website Development',
    ],
    'Health & Wellness': [
      'Personal Fitness Trainer',
      'Yoga Instructor',
      'Elderly Care & Companionship',
      'Babysitting / Child Care',
      'Pet Sitting & Dog Walking',
    ],
    'Beauty & Personal Care': [
      'Makeup Artist (At Home)',
      'Hair Stylist (At Home)',
      'Manicure & Pedicure (At Home)',
      'Henna (Mehendi) Artist',
    ],
    'Lessons & Tutoring': [
      'Academic Tutoring (Maths, Science, etc.)',
      'Music Lessons (Guitar, Piano, etc.)',
      'Language Tutor',
      'Swimming Instructor',
    ],
    'Tech & Gadget Support': [
      'On-site Tech Support',
      'Smartphone & Laptop Troubleshooting',
      'Smart Home Device Installation',
    ],
    'Professional Services': [
      'Accounting & Bookkeeping',
      'Legal Document Assistance',
      'Digital Marketing Help',
    ],
  };
}
